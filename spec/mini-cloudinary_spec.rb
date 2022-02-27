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
end