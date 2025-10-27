require "openssl"

module Redis::Cluster
  # current api
  def self.new(bootstrap : Bootstrap) : Client
    Client.new(bootstrap)
  end

  # [backward compats]
  def self.new(bootstrap : String, password : String? = nil, ssl : Bool = false, ssl_context : OpenSSL::SSL::Context::Client? = nil) : Client
    bootstraps = bootstrap.split(",").map { |b| Bootstrap.parse(b.strip).copy(pass: password, ssl: ssl, ssl_context: ssl_context) }
    Client.new(bootstraps)
  end

  # Return a Cluster Connection or Standard Connection
  def self.connect(host : String, port : Int32, password : String? = nil, ssl : Bool = false, ssl_context : OpenSSL::SSL::Context::Client? = nil) : Redis | Client
    redis = ::Redis.new(host, port, password: password, ssl: ssl, ssl_context: ssl_context)

    begin
      redis.command(["cluster", "myid"])
    rescue e : Redis::Error
      if /This instance has cluster support disabled/ === e.message
        return redis
      else
        # Just raise it because it would be a connection problem like AUTH error.
        raise e
      end
    end

    ::Redis::Cluster.new("#{host}:#{port}", password: password, ssl: ssl, ssl_context: ssl_context)
  end
end
