require "sinatra"
require "mini_magick"
require "net/http"
require "json"
require "aws-sdk-s3"

class StorageService
    MAX_LOCAL_FILES = 3
    
    def initialize(bucket_name, region)
        @latest_files = []
        @s3_client = Aws::S3::Client.new(region: region)
        @bucket_name = bucket_name
        response = @s3_client.list_buckets
        @s3_client.create_bucket(bucket: @bucket_name) unless response.include?(@bucket_name)
    end

    def get_file(filename)
        evict_old_files
        if File.file?(filename) || get_from_s3(filename)
            key_value_pair = @latest_files.find { |pair| pair[filename].nil? == false}
            key_value_pair[filename]
        else
            nil
        end
    end

    def upload(image, filename)
        @latest_files << { filename => image }
        evict_old_files
        response = @s3_client.put_object(
            bucket: @bucket_name,
            key: filename,
            body: image.to_blob
        )
        if response.etag
            return true
        else
            return false
        end
    end

    private

    def evict_old_files
        while @latest_files.size >= MAX_LOCAL_FILES
            @latest_files.shift()
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
        rescue Aws::S3::Errors::NoSuchKey => e
            false
        end
    end
end

module ErrorHandler

    STATUS_OK = 200
    STATUS_NOT_FOUND = 404
    BAD_REQUEST = 400

    def parse_error_to_json(code, message)
        json = {
            "status_code" => code,
            "error_message" => message
        }
        JSON[json]
    end

    def build_error_array(code, message)
        [code, parse_error_to_json(code, message)]
    end
end

class MiniCloudinary

    def initialize()
        @storage_service = StorageService.new("mini-cloudinary", "us-east-1")
    end

    def resize_with_background(image:, width:, height:, extent_width: width, extent_height: height, background: "black")
        image.combine_options do |c|
            c.resize("#{width}x#{height}")
            c.extent("#{extent_width}x#{extent_height}")
            c.background(background)
            c.gravity("center")
        end
    end

    def resize_image(path, filename, width, height)
        begin
            image = @storage_service.get_file(filename)
            if image.nil?
                image = MiniMagick::Image.open(path)
                if width > image.width && height > image.height
                    resize_with_background(image: image, width: image.width, height: image.height, extent_width: width, extent_height: height)
                elsif width > image.width
                    resize_with_background(image: image, width: image.width, height: height, extent_width: width)
                elsif height > image.height
                    resize_with_background(image: image, width: width, height: image.height, extent_height: height)
                else
                    image = image.resize("#{width}x#{height}")
                end
                @storage_service.upload(image, filename)
            end
            image
        rescue MiniMagick::Invalid => e
            raise IOError.new("URL not found or not an image")
        rescue OpenURI::HTTPError => e
            raise IOError.new("URL not found or not an image")
        rescue OpenSSL::SSL::SSLError => e
            raise IOError.new("Failed to open ssl connection")
        rescue SocketError => e
            raise IOError.new("Could not open connection to #{path}")
        end
    end

    def transform(url, width, height)
        if url.nil? || width.nil? || height.nil?
            raise ArgumentError.new("Arguments cannot be nil, got: url=#{url}, width=#{width}, height=#{height}")
        elsif width.to_i <= 0 || height.to_i <= 0
            raise ArgumentError.new("Width and height must be positive integers, got: width=#{width}, height=#{height}")
        else
            normalized_filename = url.strip.gsub(/[^0-9A-Za-z.\-]/, '_')
            local_path = "#{File.basename(normalized_filename)}_width=#{width}_height=#{height}.jpeg"
            image = resize_image(url, local_path, width.to_i, height.to_i)
            image.to_blob
        end
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
            content_type("image/jpeg")
            mc.transform(url, width, height)
        rescue IOError => e
            build_error_array(BAD_REQUEST, e.message)
        rescue ArgumentError => e
            build_error_array(BAD_REQUEST, e.message)
        end
    end 

end
