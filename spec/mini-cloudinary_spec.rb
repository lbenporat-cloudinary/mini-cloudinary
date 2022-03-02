require "spec_helper"

RSpec.describe App do
  def app
    App # this defines the active application for this test
  end

  describe "GET /thumbnail" do
    let(:app) { App.new }
    let(:img_url) {"https://asia.olympus-imaging.com/content/000107506.jpg"}
    context "when request is valid" do
        let(:width) { "500" }
        let(:height) { "300" }
        let(:url) { "/thumbnail?url=#{img_url}&width=#{width}&height=#{height}" }

        it "returns status 200" do
            get url
            expect(last_response.status).to eq 200
        end

        it "checks that format is jpeg" do
            get url
            expect(last_response.content_type).to eq "image/jpeg"
        end
    end

    context "when request is not valid" do
        it "returns status 404 on empty url" do
            get "/"
            expect(last_response.status).to eq 404
        end

        it "returns status 400 on empty query" do
            get "/thumbnail?"
            expect(last_response.status).to eq 400
        end
    end

    context "when parameters are invalid" do
        let(:url) { "/thumbnail?url=#{img_url}" }
        it "returns 400 on negative width" do
            width = -500
            height = 500
            get "#{url}&width=#{width}&height=#{height}"
            expect(last_response.status).to eq 400
        end

        it "returns 400 on negative height" do
            width = 500
            height = -500
            get "#{url}&width=#{width}&height=#{height}"
            expect(last_response.status).to eq 400
        end

        it "returns 400 on zero width" do
            width = 0
            height = 500
            get "#{url}&width=#{width}&height=#{height}"
            expect(last_response.status).to eq 400
        end

        it "returns 400 on zero height" do
            width = 500
            height = 0
            get "#{url}&width=#{width}&height=#{height}"
            expect(last_response.status).to eq 400
        end

        it "returns 400 on invalid width parameter" do
            width = 500
            height = 500
            get "#{url}&widh=#{width}&height=#{height}"
            expect(last_response.status).to eq 400
        end

        it "returns 400 on invalid height parameter" do
            width = 500
            height = 500
            get "#{url}&width=#{width}&heigh=#{height}"
            expect(last_response.status).to eq 400
        end

        it "returns 400 on invalid url" do
            invalid_url = "https://my-invalid-image.png"
            width = 500
            height = 500
            get "/thumbnail?url=#{invalid_url}&width=#{width}&height=#{height}"
            expect(last_response.status).to eq 400
        end
    end

    context "when resizing" do
        it "validates topmost left pixel is black on upsizing" do
            width = 8000
            height = 8000
            url = "/thumbnail?url=#{img_url}&width=#{width}&height=#{height}"
            get url
            image = MiniMagick::Image.read(last_response.body)   
            expect(image.get_pixels[0][0]).to eq [0,0,0]
        end
        
        it "validates topmost left pixel is not black on downsizing" do
            width = 8000
            height = 8000
            url = "/thumbnail?url=#{img_url}&width=#{width}&height=#{height}"
            get url
            image = MiniMagick::Image.read(last_response.body)   
            expect(image.get_pixels[0][0]).to eq [0,0,0]
        end     
    end
  end

  describe "Test resizing logic" do
    let(:app) { MiniCloudinary.new }
    let(:original_image_path) { "sample.jpeg" }
    let(:threshold) { 10 }
    def calculate_mse(rgb)
        squared = rgb.map() {|color| color ** 2}
        Math.sqrt((squared).inject(0) {|acc, val| acc + val})
    end

    def diff_mse(mse1, mse2)
        diff = mse1 - mse2
        diff.abs
    end

    context "when requested dimensions same as original" do
        it "checks that random pixel is the same as the original " do
            original_image = MiniMagick::Image.open(original_image_path)
            output_path = app.transform(original_image_path, original_image.width, original_image.height)
            transformed_image = MiniMagick::Image.read(output_path)

            x_pixel = rand(transformed_image.get_pixels.size)
            y_pixel = rand(transformed_image.get_pixels.size)
            transform_mse = calculate_mse(transformed_image.get_pixels[x_pixel][y_pixel])
            original_mse = calculate_mse(original_image.get_pixels[x_pixel][y_pixel])
            
            expect(diff_mse(transform_mse,original_mse)).to be <= threshold
        end
    end

    context "when requested dimensions with similar aspect ratio" do
        it "checks that topmost left pixel is the same as the original" do  
            original_image = MiniMagick::Image.open(original_image_path)
            output_path = app.transform(original_image_path, 200, 134)
            transformed_image = MiniMagick::Image.read(output_path)

            transform_mse = calculate_mse(transformed_image.get_pixels[0][0])
            original_mse = calculate_mse(original_image.get_pixels[0][0])

            expect(diff_mse(transform_mse,original_mse)).to be <= threshold
        end

        it "check that top right pixel is the same as the original" do
            original_image = MiniMagick::Image.open(original_image_path)
            output_path = app.transform(original_image_path, 200, 134)
            transformed_image = MiniMagick::Image.read(output_path)

            transform_mse = calculate_mse(transformed_image.get_pixels[0][transformed_image.get_pixels[0].size - 1])
            original_mse = calculate_mse(original_image.get_pixels[0][original_image.get_pixels[0].size - 1])

            expect(diff_mse(transform_mse,original_mse)).to be <= threshold
        end

        context "when dimensions are bigger than original" do
            it "checks that topmost left pixel is black" do
                output_path = app.transform(original_image_path, 1000, 1000)
                transformed_image = MiniMagick::Image.read(output_path)
    
                expect(transformed_image.get_pixels[0][0]).to eq [0,0,0]
            end            
        end

        context "when only width or height is bigger than original" do
            it "check that top center pixel is not black on bigger width" do
                original_image = MiniMagick::Image.open(original_image_path)
                output_path = app.transform(original_image_path, 1000, original_image.height)
                transformed_image = MiniMagick::Image.read(output_path)

                expect(transformed_image.get_pixels[0][500]).not_to eq [0,0,0]
            end

            it "check that left center pixel is black on bigger width" do
                original_image = MiniMagick::Image.open(original_image_path)
                output_path = app.transform(original_image_path, 1000, original_image.height)
                transformed_image = MiniMagick::Image.read(output_path)

                expect(transformed_image.get_pixels[(original_image.height / 2).floor][0]).to eq [0,0,0]
            end

            it "check that top center pixel is black on bigger height" do
                original_image = MiniMagick::Image.open(original_image_path)
                output_path = app.transform(original_image_path, original_image.width, 1000)
                transformed_image = MiniMagick::Image.read(output_path)

                expect(transformed_image.get_pixels[0][(original_image.width / 2).floor]).to eq [0,0,0]
            end

            it "check that left center pixel is not black on bigger height" do
                original_image = MiniMagick::Image.open(original_image_path)
                output_path = app.transform(original_image_path, original_image.width, 1000)
                transformed_image = MiniMagick::Image.read(output_path)

                expect(transformed_image.get_pixels[(transformed_image.height / 2).floor][0]).not_to eq [0,0,0]
            end
        end
    end
  end
end