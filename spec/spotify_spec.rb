describe Spotify do
  describe "VERSION" do
    it "is defined" do
      defined?(Spotify::VERSION).should eq "constant"
    end

    it "is the same version as in api.h" do
      spotify_version = API_H_SRC.match(/#define\s+SPOTIFY_API_VERSION\s+(\d+)/)[1]
      Spotify::API_VERSION.to_i.should eq spotify_version.to_i
    end
  end

  describe "proxying" do
    it "responds to the spotify methods" do
      Spotify.should respond_to :error_message
    end

    it "allows creating proxy methods" do
      api.should_receive(:error_message).and_return("Some error")
      Spotify.method(:error_message).call.should eq "Some error"
    end
  end

  describe ".log" do
    it "print nothing if not debugging" do
      out, err = spy_output do
        old_debug, $DEBUG = $DEBUG, false
        Spotify.log "They see me loggin'"
        $DEBUG = old_debug
      end
      out.should be_empty
      err.should be_empty
    end

    it "prints output and path if debugging" do
      suppress = true
      out, err = spy_output(suppress) do
        old_debug, $DEBUG = $DEBUG, true
        Spotify.log "Testin' Spotify log"
        $DEBUG = old_debug
      end

      out.should match "Testin' Spotify log"
      out.should match "spec/spotify_spec.rb"

      err.should be_empty
    end
  end

  describe ".try" do
    it "raises an error when the result is not OK" do
      api.should_receive(:error_example).and_return(:bad_application_key)
      expect { Spotify.try(:error_example) }.to raise_error(Spotify::Error, /BAD_APPLICATION_KEY/)
    end

    it "does not raise an error when the result is OK" do
      api.should_receive(:error_example).and_return(:ok)
      Spotify.try(:error_example).should eq :ok
    end

    it "does not raise an error when the result is not an error-type" do
      result = Object.new
      api.should_receive(:error_example).and_return(result)
      Spotify.try(:error_example).should eq result
    end

    it "does not raise an error when the resource is loading" do
      api.should_receive(:error_example).and_return(:is_loading)
      Spotify.try(:error_example).should eq :is_loading
    end
  end
end
