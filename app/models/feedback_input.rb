class FeedbackInput < ActiveRecord::Base
  attr_protected # Blacklist nothing. opposite of attr_accessible
  belongs_to :property
end
