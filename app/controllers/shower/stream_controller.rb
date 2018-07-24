class Shower::StreamController < ApplicationController
    include ActionController::Live

    before_action :close_db_connection
    skip_filter *_process_action_callbacks.map(&:filter), except: :close_db_connection

    def index
      response.headers['Content-Type'] = 'text/event-stream'
      redis = Redis.new url: ENV['REDIS_URI']

      redis.subscribe(params[:events].split(',') << 'heartbeat') do |on|
        on.message do |event, data|
          response.stream.write("event: #{event}\n")
          response.stream.write("data: #{data}\n\n")
        end
      end
    rescue ClientDisconnected, IOError
      # stream closed
    ensure
      # stopping stream thread
      redis.quit
      response.stream.close
      close_db_connection
    end

    private

    def close_db_connection
     if(defined? ActiveRecord)
      ActiveRecord::Base.connection_pool.release_connection
     elsif (defined? Mongoid)
       Mongoid::Clients.disconnect
     end
    end

end