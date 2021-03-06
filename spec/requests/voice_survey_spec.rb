require 'spec_helper'

describe "Voice Survey Interface" do

  def hash_from_xml(nokogiri_doc)
    Hash.from_xml(nokogiri_doc.to_s)
  end

  describe "initial call" do
    before(:each) do
      post 'route_to_survey'
      @body_hash = hash_from_xml(response.body)
    end
    it "prompts for property vs hood" do
      #@body_hash["Response"]["Say"].should include("enter the property code")
      @body_hash["Response"]["Gather"]["Play"].should include("welcome.mp3")
    end
    it "redirects to hood with zero" do
      post 'route_to_survey', "Digits" => ""
      @body_hash = hash_from_xml(response.body)
      @body_hash["Response"]["Redirect"].should eq("voice_survey")
      session[:survey].should eq("neighborhood")
    end
  end

  describe "neighborhood survey" do
    before(:each) do
      post 'route_to_survey', "Digits" => "0"
    end
    it "has the correct session" do
      session[:survey].should eq("neighborhood")
    end
    it "prompts with correct question" do
      pending
      post 'voice_survey'
      @body_hash = hash_from_xml(response.body)
      @body_hash["Response"]["Say"].should include("how important is public safety")
    end
    it "saves first answer" do
      post 'voice_survey'
      post 'voice_survey', { "Digits" => "1", "From" => "+16175551212" }
      FeedbackInput.find_by_phone_number("16175551212").should_not be_nil
    end
    it "saves second answer" do
      pending
      # probably remove
      post 'voice_survey'
      post 'voice_survey', { "Digits" => "1", "From" => "+16175551212" }
      @second_question_id = session[:current_question_id]
      post 'voice_survey', { "Digits" => "5", "From" => "+16175551212" }
      @input = FeedbackInput.where(:phone_number => "16175551212", :question_id => @second_question_id).first
      @input.numerical_response.should eq(5)
      FeedbackInput.where(:phone_number => "16175551212", :question_id => @second_question_id).count.should eq(1)
    end
    it "asks third (open) questions" do
      pending
      # Need to change to reflect new order
      post 'voice_survey'
      post 'voice_survey', { "Digits" => "1", "From" => "+16175551212" }
      post 'voice_survey', { "Digits" => "5", "From" => "+16175551212" }
      @body_hash = hash_from_xml(response.body)
      @body_hash["Response"]["Say"].should include("to give voice feedback")
    end
    it "asks third (open) question and saves answer" do
      post 'voice_survey'
      post 'voice_survey', { "Digits" => "1", "From" => "+16175551212" }
      post 'voice_survey', { "Digits" => "5", "From" => "+16175551212" }
      @third_question_id = session[:current_question_id]
      post 'voice_survey', { "RecordingUrl" => "https://s3-us-west-1.amazonaws.com/south-bend-secrets/121gigawatts.mp3", "From" => "+16175551212" }
      @saved_input = FeedbackInput.where(:phone_number => "16175551212", :question_id => @third_question_id).first
      @saved_input.voice_file_url.should eq("https://s3-us-west-1.amazonaws.com/south-bend-secrets/121gigawatts.mp3")
    end
  end

  describe "property survey" do
    before(:each) do
      post 'route_to_survey', "Digits" => "1234"
    end
    it "has the correct session survey" do
      session[:survey].should eq("property")
    end
    it "sets :property_id in session" do
      session[:property_id].should eq(2)
    end
    it "prompts with correct question" do
      pending
      post 'voice_survey'
      @body_hash = hash_from_xml(response.body)
      # Needs to use Play
      @body_hash["Response"]["Say"].should include("if you want to repair this property")
    end
    it "saves input for property_outcome question" do
      post 'voice_survey'
      @prop_outcome_question_id = session[:current_question_id]
      post 'voice_survey', { "Digits" => "1", "From" => "+16175551212" }
      @input = FeedbackInput.where(:phone_number => "16175551212", :question_id => @prop_outcome_question_id).first
      @input.numerical_response.should eq(1)
      FeedbackInput.where(:phone_number => "16175551212", :question_id => @prop_outcome_question_id, :property_id => session[:property_id]).count.should eq(1)
    end
    it "gets to open neighborhood question successfully" do
      pending
      # Survey changed
      post 'voice_survey'
      post 'voice_survey', { "Digits" => "1", "From" => "+16175551212" }
      post 'voice_survey', { "Digits" => "4", "From" => "+16175551212" }
      post 'voice_survey', { "Digits" => "5", "From" => "+16175551212" }
      @ncomment_question_id = session[:current_question_id]
      post 'voice_survey', { "RecordingUrl" => "https://s3-us-west-1.amazonaws.com/south-bend-secrets/121gigawatts.mp3", "From" => "+16175551212" }
      @saved_input = FeedbackInput.where(:phone_number => "16175551212", :question_id => @ncomment_question_id, :neighborhood_id => session[:neighborhood_id]).first
      @saved_input.voice_file_url.should eq("https://s3-us-west-1.amazonaws.com/south-bend-secrets/121gigawatts.mp3")
    end
    it "saves neighborhood voice question correctly" do
      pending
      # New ordering
      post 'voice_survey'
      post 'voice_survey', { "Digits" => "1", "From" => "+16175551212" }
      post 'voice_survey', { "Digits" => "4", "From" => "+16175551212" }
      post 'voice_survey', { "Digits" => "5", "From" => "+16175551212" }
      @ncomment_question_id = session[:current_question_id]
      post 'voice_survey', { "RecordingUrl" => "https://s3-us-west-1.amazonaws.com/south-bend-secrets/121gigawatts.mp3", "From" => "+16175551212" }
      @saved_input = FeedbackInput.where(:phone_number => "16175551212", :question_id => @ncomment_question_id, :neighborhood_id => session[:neighborhood_id]).first
      @saved_input.voice_file_url.should eq("https://s3-us-west-1.amazonaws.com/south-bend-secrets/121gigawatts.mp3")
      @saved_input = FeedbackInput.where(:phone_number => "16175551212", :question_id => @ncomment_question_id, :neighborhood_id => session[:neighborhood_id]).count.should eq(1)
    end
    it "prompts with property voice question at end" do
      pending
      # Survey has changed
      post 'voice_survey'
      post 'voice_survey', { "Digits" => "1", "From" => "+16175551212" }
      post 'voice_survey', { "Digits" => "4", "From" => "+16175551212" }
      post 'voice_survey', { "Digits" => "5", "From" => "+16175551212" }
      post 'voice_survey', { "RecordingUrl" => "https://s3-us-west-1.amazonaws.com/south-bend-secrets/121gigawatts.mp3", "From" => "+16175551212" }
      @body_hash = hash_from_xml(response.body)
      # Need to change below to Play
      @body_hash["Response"]["Say"].should eq(Question.find(session[:current_question_id]).voice_text) #include("")
    end
    it "saves property voice question correctly" do
      pending
      # Survey has changed
      post 'voice_survey'
      post 'voice_survey', { "Digits" => "1", "From" => "+16175551212" }
      post 'voice_survey', { "Digits" => "4", "From" => "+16175551212" }
      post 'voice_survey', { "Digits" => "5", "From" => "+16175551212" }
      post 'voice_survey', { "RecordingUrl" => "https://s3-us-west-1.amazonaws.com/south-bend-secrets/121gigawatts.mp3", "From" => "+16175551212" }
      @pcomment_question_id = session[:current_question_id]
      post 'voice_survey', { "RecordingUrl" => "https://s3-us-west-1.amazonaws.com/south-bend-secrets/121gigawatts.mp3", "From" => "+16175551212" }
      @saved_input = FeedbackInput.where(:phone_number => "16175551212", :question_id => @pcomment_question_id, :neighborhood_id => session[:neighborhood_id]).first
      @saved_input.voice_file_url.should eq("https://s3-us-west-1.amazonaws.com/south-bend-secrets/121gigawatts.mp3")
      FeedbackInput.where(:phone_number => "16175551212", :question_id => @pcomment_question_id, :neighborhood_id => session[:neighborhood_id]).count.should eq(1)
    end
  end

end

