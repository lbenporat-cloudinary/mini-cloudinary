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

    def resize_with_black_background(image, width, height)
        image.combine_options do |c|
            c.extent("#{width}x#{height}")
            c.background("black")
            c.gravity("center")
        end
    end

    def resize_image(path, output_path, width, height)
        begin
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
            output_path
        rescue Exception => e
            [BAD_REQUEST, parse_error_to_json(BAD_REQUEST, "url not found or not an image")]
        end
    end

    def handle_request(url, width, height)
        if width.nil? || height.nil? || width.to_i <= 0 || height.to_i <= 0
            [BAD_REQUEST, parse_error_to_json(BAD_REQUEST, "Invalid params")]
        else
            resize_image(url, @local_path, width.to_i, height.to_i)
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
