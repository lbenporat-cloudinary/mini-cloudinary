require "sinatra"
require "mini_magick"
require "net/http"
require 'json'

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

    def resize_with_background(image:, width:, height:, background: "black")
        image.combine_options do |c|
            c.extent("#{width}x#{height}")
            c.background(background)
            c.gravity("center")
        end
    end

    def resize_image(path, output_path, width, height)
        begin
            image = MiniMagick::Image.open(path)
            if width > image.width && height > image.height
                resize_with_background(image: image, width: width, height: height)
            elsif width > image.width || height > image.height
                image = image.resize("#{width}x#{height}")
                resize_with_black_background(image, width, height)
            else
                image = image.resize("#{width}x#{height}")
            end
            image.write("#{output_path}")
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

    def transform(url, local_path, width, height)
        if url.nil? || width.nil? || height.nil?
            raise ArgumentError.new("Arguments cannot be nil, got: url=#{url}, width=#{width}, height=#{height}")
        elsif width.to_i <= 0 || height.to_i <= 0
            raise ArgumentError.new("Width and height must be positive integers, got: width=#{width}, height=#{height}")
        else
            resize_image(url, local_path, width.to_i, height.to_i)
            local_path
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

        normalized_url = url.strip.gsub(/[^0-9A-Za-z.\-]/, '_')
        local_path = "#{File.basename(normalized_url)}_width=#{width}_height=#{height}.jpeg"

        begin
            send_file(mc.transform(url, local_path, width, height))
        rescue IOError => e
            build_error_array(BAD_REQUEST, e.message)
        rescue ArgumentError => e
            build_error_array(BAD_REQUEST, e.message)
        end
    end 

end
