require "uri"
require "openssl"

module Redis::Cluster
  record Bootstrap,
    host : String? = nil,
    port : Int32? = nil,
    sock : String? = nil,
    pass : String? = nil,
    ssl : Bool = false,
    ssl_context : OpenSSL::SSL::Context::Client? = nil,
    reconnect : Bool = true do
    def host
      if @host && @host =~ /:/
        raise "invalid hostname: #{@host}"
      end
      @host || "127.0.0.1"
    end

    def port
      @port || 6379
    end

    def sock?
      !!@sock
    end

    def pass? : String?
      # empty string should be treated as nil for redis password
      @pass.to_s.empty? ? nil : @pass.to_s
    end

    # aliases
    def pass
      pass?
    end

    def password
      pass
    end

    def unixsocket
      sock
    end

    def ssl?
      @ssl
    end

    def ssl_context
      @ssl_context ||= begin
        context = OpenSSL::SSL::Context::Client.new
        context.ciphers = "EECDH+AESGCM:EDH+AESGCM:AES256+EECDH:AES256+EDH"
        context.add_options(OpenSSL::SSL::Options::NO_SSL_V2 | OpenSSL::SSL::Options::NO_SSL_V3)
        context.verify_mode = OpenSSL::SSL::VerifyMode::None
        context
      end
    end

    def copy(host : String? = nil, port : Int32? = nil, sock : String? = nil, pass : String? = nil, ssl : Bool? = nil, ssl_context : OpenSSL::SSL::Context::Client? = nil, reconnect : Bool? = nil)
      Bootstrap.new(
        host: host || @host,
        port: port || @port,
        sock: sock || @sock,
        pass: pass || pass?,
        ssl: ssl.nil? ? @ssl : ssl,
        ssl_context: ssl_context,
        reconnect: reconnect.nil? ? @reconnect : reconnect,
      )
    end

    def redis
      ssl_ctx = @ssl ? ssl_context : nil
      Redis.new(host: host, port: port, unixsocket: @sock, password: @pass, ssl: @ssl, ssl_context: ssl_ctx, reconnect: @reconnect, command_timeout: 10.seconds, connect_timeout: 10.seconds)
    rescue err : Redis::CannotConnectError
      if sock?
        raise Redis::CannotConnectError.new("file://#{@sock}")
      else
        raise err
      end
    end

    def to_s(secure = true)
      auth = nil
      auth = "#{pass}@" if pass
      auth = "[FILTERED]@" if pass && secure

      scheme = @ssl ? "rediss" : "redis"

      if sock?
        "#{scheme}://%s%s" % [auth, sock]
      else
        "#{scheme}://%s%s:%s" % [auth, host, port]
      end
    end

    def to_s(io : IO)
      io << to_s
    end

    def self.zero
      new(host: Addr::DEFAULT_HOST, port: Addr::DEFAULT_PORT, pass: nil, ssl: false)
    end

    def self.parse(s : String, reconnect : Bool = true)
      case s
      when %r{\Arediss?://}
        # normalized
      when %r{\A([a-z0-9\.\+-]+):/}
        raise "unknown scheme for Bootstrap: `#{$1}`"
      else
        s = "redis://#{s}"
      end

      uri = URI.parse(s)

      # `URI.parse("redis:///")` now builds `host` as `""` rather than `nil` (#6323 in crystal-0.29)
      host = uri.host.to_s.presence
      pass = uri.user.to_s.presence
      path = uri.path.to_s.presence
      ssl = uri.scheme == "rediss"

      if path && host.nil? && uri.port.nil?
        return new(sock: path, pass: pass, ssl: ssl)
      end

      if uri.port && uri.port.not_nil! <= 0
        raise "invalid port for Bootstrap: `#{uri.port}`"
      end

      zero.copy(host: host, port: uri.port, pass: pass, ssl: ssl, reconnect: reconnect)
    end
  end
end
