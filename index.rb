require 'sinatra'
require 'shotgun'
require 'haml'
require 'sass'
require 'bson'
require 'mongoid'
require 'carrierwave'
require 'carrierwave/mongoid'

configure do
  Mongoid.configure do |config|
    name = "simple_galery"
    config.master = Mongo::Connection.new.db(name)
    config.persist_in_safe_mode = false
  end
end

class ImageUploader < CarrierWave::Uploader::Base
  include CarrierWave::MiniMagick
  storage :file
  
  def filename
     "#{secure_token(10)}.#{file.extension}" if original_filename.present?
  end
  
  version :thumb_gray do
    process :resize_to_fill => [200, 200]
    process :convert_to_grayscale
  end
  
  version :thumb do
    process :resize_to_fill => [200, 200]
    process :merge
  end
  
  def convert_to_grayscale
    manipulate! do |img|
      img.colorspace("Gray")
      img.brightness_contrast("+15x0")
      img = yield(img) if block_given?
      img
    end
  end

  def merge
    manipulate! do |img|
      img.combine_options do |cmd|
        cmd.gravity "north"
        cmd.extent "200x400"
      end

      img = img.composite(::MiniMagick::Image.open(model.image.thumb_gray.current_path, "jpg")) do |c|
        c.gravity "south"
      end
      img = yield(img) if block_given?
      img
    end
  end
  
  protected
  
  def secure_token(length = 16)
    model.image_secure_token ||= SecureRandom.hex(length / 2)
  end
end

class Image
  include Mongoid::Document
  mount_uploader :image, ImageUploader, type: String
  field :title, type: String
  field :image_secure_token, type: String
end

get '/' do
  @images = Image.all
  haml :index
end

post '/' do
  @image = Image.new(:title => params[:title], :image => params[:image])
  @image.save
  redirect '/'
end

get '/recreate' do
  Image.all.each do |image|
    image.image.recreate_versions!
  end
end

get '/images/:id' do
  @image = Image.find(params[:id])
  haml :show
end

not_found do
  status 404
  "Something is missing! We try to find it..."
end
