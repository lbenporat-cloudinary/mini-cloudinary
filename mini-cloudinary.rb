require 'sinatra'
require 'mini_magick'
require 'net/http'
require 'json'
require 'aws-sdk-s3'

class StorageService

  MAX_LOCAL_FILES = 3

  def initialize(bucket_name, region)
    @latest_files = []
    @s3_client = Aws::S3::Client.new(endpoint: "http://192.168.1.29:9000",
      access_key_id: 'minioadmin',
      secret_access_key: 'minioadmin',
      force_path_style: true,
      region: region)
    @bucket_name = bucket_name
    @s3_client.create_bucket(bucket: @bucket_name) unless bucket_exists?
  end

  def get_image(filename)
    evict_old_files
    key_value_pair = @latest_files.find { |pair| pair[filename].nil? == false }
    if key_value_pair.nil?
      get_from_s3(filename)
      key_value_pair = @latest_files.find { |pair| pair[filename].nil? == false }
    end

    # still nil, couldn't get it from s3 as well...
    key_value_pair.nil? ? nil : key_value_pair[filename]
  end

  def upload(image, filename)
    @latest_files << { filename => image }
    evict_old_files
    response = @s3_client.put_object(
      bucket: @bucket_name,
      key: filename,
      body: image.to_blob
    )
    response.etag ? true : false
  end

private

  def evict_old_files
    while @latest_files.size >= MAX_LOCAL_FILES
      @latest_files.shift
    end
  end

  def get_from_s3(filename)
    begin
      response = @s3_client.get_object(
        response_target: filename,
        bucket: @bucket_name,
        key: filename
      )
      if response.etag
        @latest_files << { filename => MiniMagick::Image.open(filename) }
        File.delete(filename)
        true
      else
        false
      end
    rescue Aws::S3::Errors::NoSuchKey
      false
    end
  end

  def bucket_exists?
    response = @s3_client.list_buckets
    response.buckets.each do |bucket|
       return true if bucket.name == @bucket_name
    end
    false
  end
end

module ErrorHandler
  STATUS_OK = 200
  STATUS_NOT_FOUND = 404
  BAD_REQUEST = 400

  def parse_error_to_json(code, message)
    json = {
     'status_code' => code,
     'error_message' => message
    }
    JSON[json]
  end

  def build_error_array(code, message)
    [code, parse_error_to_json(code, message)]
  end
end

class MiniCloudinary

  def initialize
    @storage_service = StorageService.new('mini-cloudinary', 'us-east-1')
  end

  def resize_with_background(image:, width:, height:, extent_width: width, extent_height: height, background: "black")
    image.combine_options do |c|
      c.resize("#{width}x#{height}")
      c.extent("#{extent_width}x#{extent_height}")
      c.background(background)
      c.gravity('center')
    end
  end

  def resize_image(image, width, height)
    if width > image.width && height > image.height
      resize_with_background(image: image, width: image.width, height: image.height, extent_width: width, extent_height: height)
    elsif width > image.width
      resize_with_background(image: image, width: image.width, height: height, extent_width: width)
    elsif height > image.height
      resize_with_background(image: image, width: width, height: image.height, extent_height: height)
    else
      image = image.resize("#{width}x#{height}")
    end
    image
  end

  def transform(url, width, height)
    if url.nil? || width.nil? || height.nil?
      raise ArgumentError.new("Arguments cannot be nil, got: url=#{url}, width=#{width}, height=#{height}")
    elsif width.to_i <= 0 || height.to_i <= 0
      raise ArgumentError.new("Width and height must be positive integers, got: width=#{width}, height=#{height}")
    end

    normalized_filename = url.strip.gsub(/[^0-9A-Za-z.\-]/, '_')
    filename = "#{File.basename(normalized_filename)}_width=#{width}_height=#{height}.jpeg"
    
    image = @storage_service.get_image(filename)
    if image.nil?
      image = create_new_transformation(url, filename, width, height)
    end
    image.to_blob
  end

  def create_new_transformation(url, filename, width, height)
    begin
      image = MiniMagick::Image.open(url)
      image = resize_image(image, width.to_i, height.to_i)
      @storage_service.upload(image, filename)
    rescue MiniMagick::Invalid
      raise IOError.new('URL not found or not an image')
    rescue OpenURI::HTTPError
      raise IOError.new('URL not found or not an image')
    rescue OpenSSL::SSL::SSLError
      raise IOError.new('Failed to open ssl connection')
    rescue SocketError
      raise IOError.new("Could not open connection to #{url}")
    end
    image
  end
end

class App < Sinatra::Base
  include ErrorHandler

  mc = MiniCloudinary.new

  error STATUS_NOT_FOUND do
    parse_error_to_json(STATUS_NOT_FOUND, "Sorry, this page doesn't exist")
  end

  get '/thumbnail' do
    # matches "/thumbnail?url=<url>​&width=<width>​&height=<height>"
    url = params['url']
    width = params['width']
    height = params['height']

    begin
      content_type('image/jpeg')
      mc.transform(url, width, height)
    rescue IOError => e
      build_error_array(BAD_REQUEST, e.message)
    rescue ArgumentError => e
      build_error_array(BAD_REQUEST, e.message)
    end
  end
end
