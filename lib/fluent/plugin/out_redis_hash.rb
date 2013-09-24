module Fluent
  class RedisHashOutput < BufferedOutput
    Fluent::Plugin.register_output('redis_hash', self)
    attr_reader :host, :port, :db_number, :redis

    def initialize
      super
      require 'redis'
      require 'redis/distributed'
      require 'json'
      require 'msgpack'
    end

    def configure(conf)
      super

      @urls = conf.has_key?('urls') ? conf['urls'].split(',').map(&:strip) : ['redis://localhost:6379']
      @password = conf.has_key?('password') ? conf['password'].to_i : nil
      @db_number = conf.has_key?('db_number') ? conf['db_number'].to_i : nil
      @hash_key_pattern = conf.has_key?('hash_key_pattern') ? conf['hash_key_pattern'].to_s.gsub('%','#') : nil
      @hash_field_pattern = conf.has_key?('hash_field_pattern') ? conf['hash_field_pattern'].to_s.gsub('%','#') : nil
      @hash_value_pattern = conf.has_key?('hash_value_pattern') ? conf['hash_value_pattern'].to_s.gsub('%','#') : nil
    end

    def start
      super
      @redis = if @urls.size > 1
        Redis::Distributed.new(@urls, :thread_safe => true, :db => @db_number, :password => @password)
      else
        Redis.new(:url => @urls.first, :thread_safe => true, :db => @db_number, :password => @password)
      end
      eval %{
        def get_hash_key(record)
          "#{@hash_key_pattern}"
        end 
        def get_hash_field(record)
          "#{@hash_field_pattern}"
        end 
        def get_hash_value(record)
          "#{@hash_value_pattern}"
        end 
      }
    end

    def shutdown
      @redis.quit
    end

    def format(tag, time, record)
      identifier = [tag, time].join(".")
      [identifier, record].to_msgpack
    end

    def write(chunk)
#      @redis.pipelined {
        chunk.open { |io|
          begin
            MessagePack::Unpacker.new(io).each.each_with_index { |data, index|
              record = data[1]
              p get_hash_key(record)
              @redis.mapped_hmset get_hash_key(record), {get_hash_field(record) => get_hash_value(record)}
            }
          rescue EOFError
            # EOFError always occured when reached end of chunk.
          end
        }
#      }
    end
  end
end
