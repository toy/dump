# Be sure to restart your server when you modify this file.

# Your secret key for verifying cookie session data integrity.
# If you change this key, all old sessions will become invalid!
# Make sure the secret is at least 30 characters and all random, 
# no regular words or you'll be exposed to dictionary attacks.
ActionController::Base.session = {
  :key         => '_dummy-2.3_session',
  :secret      => '75e2e6143532b7095b454f717b27d47b79b9e86c91202bc27f670c0eeef4ea98936719d78a3c61c13964f0cc7bb77be67d0b125ae72fcf98d4ba6c47fcb47514'
}

# Use the database for sessions instead of the cookie-based default,
# which shouldn't be used to store highly confidential information
# (create the session table with "rake db:sessions:create")
# ActionController::Base.session_store = :active_record_store
