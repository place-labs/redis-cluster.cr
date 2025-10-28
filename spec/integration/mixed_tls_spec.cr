require "../spec_helper"

# Integration tests that verify both TLS and non-TLS functionality work
describe "Mixed TLS/Non-TLS Integration" do
  describe "Standard Redis (non-TLS)" do
    it "should create standard Redis instance" do
      redis = Redis.new(host: "localhost", port: 6379)
      redis.should be_a(Redis)
      # Don't actually connect in tests - just verify the instance is created correctly
    end
  end

  describe "TLS Redis" do
    it "should create TLS Redis instance" do
      context = OpenSSL::SSL::Context::Client.new
      context.ciphers = "EECDH+AESGCM:EDH+AESGCM:AES256+EECDH:AES256+EDH"
      context.add_options(OpenSSL::SSL::Options::NO_SSL_V2 | OpenSSL::SSL::Options::NO_SSL_V3)
      context.verify_mode = OpenSSL::SSL::VerifyMode::None
      redis = Redis.new(host: "localhost", port: 6380, ssl: true, ssl_context: context)
      redis.should be_a(Redis)
      # Don't actually connect in tests - just verify the instance is created correctly
    end
  end

  describe "Cluster Bootstrap" do
    it "should create standard cluster bootstrap" do
      bootstrap = Redis::Cluster::Bootstrap.new(host: "localhost", port: 6379)
      bootstrap.ssl?.should be_false
      bootstrap.host.should eq("localhost")
      bootstrap.port.should eq(6379)
    end

    it "should create TLS cluster bootstrap" do
      bootstrap = Redis::Cluster::Bootstrap.new(host: "localhost", port: 6380, ssl: true)
      bootstrap.ssl?.should be_true
      bootstrap.host.should eq("localhost")
      bootstrap.port.should eq(6380)
    end
  end

  describe "Cluster Client" do
    it "should work with standard Redis configuration" do
      bootstrap = Redis::Cluster::Bootstrap.new(host: "localhost", port: 6379)
      client = Redis::Cluster::Client.new([bootstrap])

      client.should be_a(Redis::Cluster::Client)
    end

    it "should work with TLS Redis configuration" do
      bootstrap = Redis::Cluster::Bootstrap.new(host: "localhost", port: 6380, ssl: true)
      client = Redis::Cluster::Client.new([bootstrap])

      client.should be_a(Redis::Cluster::Client)
    end
  end

  describe "URL Parsing" do
    it "should parse standard Redis URLs" do
      bootstrap = Redis::Cluster::Bootstrap.parse("redis://testpassword@redis:6379")
      bootstrap.ssl?.should be_false
      bootstrap.host.should eq("redis")
      bootstrap.port.should eq(6379)
      bootstrap.password.should eq("testpassword")
    end

    it "should parse TLS Redis URLs" do
      bootstrap = Redis::Cluster::Bootstrap.parse("rediss://testpassword@redis-tls:6380")
      bootstrap.ssl?.should be_true
      bootstrap.host.should eq("redis-tls")
      bootstrap.port.should eq(6380)
      bootstrap.password.should eq("testpassword")
    end
  end
end
