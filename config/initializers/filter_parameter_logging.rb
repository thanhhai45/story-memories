# Không ghi bí mật hay nội dung riêng tư vào log.
Rails.application.config.filter_parameters += [
  :passw, :email, :secret, :token, :_key, :crypt, :salt, :certificate, :otp, :ssn, :cvv, :cvc,
  :api_key, :story_notes, :narration, :ending, :caption, :person_names
]
