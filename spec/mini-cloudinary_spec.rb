require "spec_helper"

RSpec.describe App do
  def app
    App # this defines the active application for this test
  end

  describe "GET /thumbnail" do
    let(:app) { App.new }
    let(:img_url) {"https://asia.olympus-imaging.com/content/000107506.jpg"}
    context "basic get" do

        let(:width) { "500" }
        let(:height) { "300" }
        let(:url) { "/thumbnail?url=#{img_url}&width=#{width}&height=#{height}" }
        it "test valid request returns status 200 OK" do
            get url
            expect(last_response.status).to eq 200
        end

        it "test invalid request returns 404" do
            get "/"
            expect(last_response.status).to eq 404
        end

        it "test empty query" do
            get "/thumbnail?"
            expect(last_response.status).to eq 400
        end

        it "test return format is jpeg" do
            get url
            expect(last_response.content_type).to eq "image/jpeg"
        end
    end

    context "Invalid params" do
        let(:url) { "/thumbnail?url=#{img_url}" }
        it "test negative width returns 400" do
            width = -500
            height = 500
            get "#{url}&width=#{width}&height=#{height}"
            expect(last_response.status).to eq 400
        end

        it "test negative height returns 400" do
            width = 500
            height = -500
            get "#{url}&width=#{width}&height=#{height}"
            expect(last_response.status).to eq 400
        end

        it "test zero width returns 400" do
            width = 0
            height = 500
            get "#{url}&width=#{width}&height=#{height}"
            expect(last_response.status).to eq 400
        end

        it "test zero height returns 400" do
            width = 500
            height = 0
            get "#{url}&width=#{width}&height=#{height}"
            expect(last_response.status).to eq 400
        end

        it "test invalid width param returns 400" do
            width = 500
            height = 500
            get "#{url}&widh=#{width}&height=#{height}"
            expect(last_response.status).to eq 400
        end

        it "test invalid height param returns 400" do
            width = 500
            height = 500
            get "#{url}&width=#{width}&heigh=#{height}"
            expect(last_response.status).to eq 400
        end
    end

    context "test padding" do

        it "test black background on upsizing" do
            width = 8000
            height = 8000
            url = "/thumbnail?url=#{img_url}&width=#{width}&height=#{height}"
            get url
            image = MiniMagick::Image.read(last_response.body)   
            expect(image.get_pixels[0][0]).to eq [0,0,0]
        end
        
        it "test no black background on downsizing" do
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