namespace :reset do

  desc "Resets voice files"
  task voice_files: :environment do
    if VoiceFile.count > 0
      VoiceFile.delete_all
    end
    def s3_path_for(filename)
      "https://s3-us-west-1.amazonaws.com/south-bend-secrets/#{filename}.mp3"
    end
    ["neighborhood_comments", "property_comments", "property_outcome", "property_values", "public_safety", "thanks", "welcome_property", "wrong_property_id"].each do |short_name|
      VoiceFile.create!(short_name: short_name, url: s3_path_for(short_name))
    end
  end

  desc "Resets the Questions table with the questions in this file"
  task questions: :environment do
    if Question.count > 0
      Question.delete_all
    end
    Question.create!( \
      [ \
        {voice_text: "On a scale of 1-5 how important is public safety in your neighborhood? Press the corresponding number on your phone to record your response 1 being not important and 5 being very important.", \
          question_text: "Importance of Neighborhood Public Safety", \
          short_name: "public_safety", \
          feedback_type: "numerical_response" }, \
        {voice_text: "On a scale of 1-5 how important is improving property values in your neighborhood? Press the corresponding number on your phone to record your response 1 being not important and 5 being very important.", \
          question_text: "Importance of Neighborhood Property Values", \
          short_name: "property_values", \
          feedback_type: "numerical_response" }, \
        {voice_text: "Thanks! After the tone you will have a minute to give voice feedback on important issues in your neighborhood. Please remember all feedback will be posted on a public website.", \
          short_name: "neighborhood_comments", \
          feedback_type: "voice_file" }, \
        {voice_text: "Press 1 if you want to repair this property. Press 2 if you want to  remove this property. Press 3 if you want to something else to happen to this property.", \
          short_name: "property_outcome", \
          feedback_type: "numerical_response" }, \
        {voice_text: "Because you entered feedback on a specific property you will have an additional minute to leave voice feedback on that property after the tone. Again all feedback is public.", \
          short_name: "property_comments", \
          feedback_type: "voice_file" }, \
          {voice_text: "The property code you entered cannot be found, please try again.", \
          short_name: "wrong_property_id", \
          feedback_type: "voice_file" } \
      ] )
    Question.all.each do |question|
      question.update_attribute(:voice_file_id, VoiceFile.find_by_short_name(question.short_name).id)
    end
  end

end
