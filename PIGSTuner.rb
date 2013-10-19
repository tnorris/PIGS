# PIGSTuner.rb
# A wrapper around the grooveshark rubygem

require 'grooveshark'
require 'thread'
require 'active_support/all'
require 'pp'

class PIGSTuner
  def initialize (opts={})
    @options = opts
    @log = @options.log
    init_grooveshark
    @read_io, @write_io = IO.pipe
    @child = nil
    @mutex = Mutex.new

    @backend_command = "#{@options.backend} #{@options.arguments.join ' '}"
  end

  def init_grooveshark
    @log.info "Initializing new Grooveshark session"
    @expiration_date = Time.now + (24*60*60)
    @grooveshark_client = Grooveshark::Client.new
    @grooveshark_session = @grooveshark_client.session
  end

  def session_expired?
    return Time.now > @expiration_date
  end

  # Asks Grooveshark for a song url and plays it
  # Returns JSON encoded success message
  def play_song_with_id(id)
    begin
      @mutex.synchronize do
        unless @child.nil? then
          execute_tuner_command("stop")
        end
        while !@child.nil? do
          sleep 1
        end
        url = @grooveshark_client.get_song_url_by_id(id)
        @child = fork do
          STDIN.reopen(@read_io)
          @log.debug('PIGSTuner') {url}
          @log.info('PIGSTuner') {"execing: #{@backend_command.gsub('PIGSURL', url)}"}
          `#{@backend_command.gsub('PIGSURL', url)}`
          exit
        end
        Thread.new {
          Process.waitpid(@child)
          @child = nil
        }
      end
    rescue Exception
      return {"success" => false}.to_json
    end
    return {"success" => true}.to_json
  end

  # Search for a Grooveshark track
  # Returns a JSON array of the results, or nil
  def search(query)
    # Check if we need a new Grooveshark session
    if session_expired?
      init_grooveshark
    end
    query.strip!

    songs = []
    begin
      songs = @grooveshark_client.search_songs(query)
    rescue Exception
    end

    unless songs.length == 0
      return songs.to_json
    else
      return nil
    end
  end

  # Searches Grooveshark and plays the first result
  # Returns JSON object of song playing, or nil
  def im_feeling_lucky(query)
    # Check if we need a new Grooveshark session
    if session_expired?
      init_grooveshark
    end
    query.strip!

    # Ask Grooveshark for a song
    songs = []
    begin
      songs = @grooveshark_client.search_songs(query)
    rescue Exception
    end
    song = songs.first

    # If we got a song, play it
    unless song.nil?
      play_song_with_id(song.id)
      return song.to_json
    else
      return nil
    end
  end

  # Playback controls
  # Returns JSON encoded success message
  def execute_tuner_command(command)
    commands = {
        "pause_unpause" => " ",
        "stop" => "q"
    }
    if commands.has_key?(command)
      @write_io.write "#{commands[command]}"
      return {"success" => true}.to_json
    else
      return {"success" => false}.to_json
    end
  end
end
