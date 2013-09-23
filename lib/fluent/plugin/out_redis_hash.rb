module Fluent
  class RedisOutput < BufferedOutput
    Fluent::Plugin.register_output('redis', self)
    attr_reader :host, :port, :db_number, :redis

    def initialize
      super
      require 'redis'
      require 'json'
    end

    def configure(conf)
      super

      @urls = conf.has_key?('host') ? conf['host'].split(',').map(&:strip) : ['redis://localhost:6379']
      @password = conf.has_key?('password') ? conf['password'].to_i : nil
      @db_number = conf.has_key?('db_number') ? conf['db_number'].to_i : nil
      @key_pattern
      @field_pattern
      
    end

    def start
      super
      @redis = if @urls.size > 1
        require 'redis/distributed'
        Redis::Distributed.new(urls, :thread_safe => true, :db => @db_number, :password => @password)
      else
        Redis.new(:url => urls.first, :thread_safe => true, :db => @db_number, :password => @password)
      end
    end

    def shutdown
      @redis.quit
    end

    def format(tag, time, record)
      identifier = [tag, time].join(".")
    end

    def write(chunk)
      @redis.pipelined {
        chunk.open { |io|
          begin
            p JSON.parse.(io.read)
          rescue EOFError
            # EOFError always occured when reached end of chunk.
          end
        }
      }
    end
  end
end