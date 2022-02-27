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
end

class MiniCloudinary

    include ErrorHandler

    def initialize(path)
        @local_path = path
    end

    def image_doesnt_exist?(url)
        if url.nil?
            return false
        end
        
        uri = URI.parse(url)
        request = Net::HTTP.new(uri.host, uri.port)
        request.use_ssl = (uri.scheme == 'https')
        response = request.request_head(uri.path)
        response.code.to_i != STATUS_OK
    end

    def resize_with_black_background(image, width, height)
        image.combine_options do |c|
            c.extent("#{width}x#{height}")
            c.background("black")
            c.gravity("center")
        end
    end

    def resize_image(path, output_path, width, height)
        image = MiniMagick::Image.open(path)
        if width > image.width && height > image.height
            resize_with_black_background(image, width, height)
        elsif width > image.width || height > image.height
            image = image.resize("#{width}x#{height}")
            resize_with_black_background(image, width, height)
        else
            image = image.resize("#{width}x#{height}")
        end
        image.write("#{output_path}")
    end

    def handle_request(url, width, height)
        if image_doesnt_exist?(url) # todo check that it is actually and image!
            [BAD_REQUEST, parse_error_to_json(BAD_REQUEST, "url not found or not an image")]
        elsif width.nil? || height.nil? || width.to_i <= 0 || height.to_i <= 0
            [BAD_REQUEST, parse_error_to_json(BAD_REQUEST, "Invalid params")]
        else
            resize_image(url, @local_path, width.to_i, height.to_i)
            @local_path
        end
    end
end

class App < Sinatra::Base

    include ErrorHandler

    file_path = "output.jpeg"
    mc = MiniCloudinary.new(file_path)

    error STATUS_NOT_FOUND do
        parse_error_to_json(STATUS_NOT_FOUND, "Sorry, this page doesn't exist")
    end

    get '/thumbnail' do    
        # matches "/thumbnail?url=<url>​&width=<width>​&height=<height>"
        url = params['url']
        width = params['width']
        height = params['height']

        ret_value = mc.handle_request(url, width, height)
        if ret_value.is_a?(String)
            send_file(file_path) 
        else
            ret_value
        end
    end 

end
