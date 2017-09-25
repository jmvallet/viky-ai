require "application_system_test_case"

class AuthenticationTest < ApplicationSystemTestCase


  test 'Sign up failed without email and password' do
    FLIPPER.enable :user_registration
    visit new_user_registration_path

    click_button 'Sign up'

    expected = [
      "Email can't be blank",
      "Password can't be blank"
    ]
    assert_equal expected, all('.help--error').collect {|n| n.text}
    assert_equal '/users', current_path
  end


  test 'Sign up failed with a too short password' do
    FLIPPER.enable :user_registration
    visit new_user_registration_path

    fill_in 'Email', with: 'superman@voqal.ai'
    fill_in 'Password', with: 'short'

    click_button 'Sign up'

    expected = [
      "Password is too short (minimum is 6 characters)"
    ]
    assert_equal expected, all('.help--error').collect {|n| n.text}
    assert_equal '/users', current_path
  end


  test 'Sign up failed with duplicate email' do
    FLIPPER.enable :user_registration
    # First successful sign in
    visit new_user_registration_path
    fill_in 'Email', with: 'superman@voqal.ai'
    fill_in 'Password', with: 'great password baby!'

    # TODO: Remove this as soon as possible
    User.any_instance.stubs('active_for_authentication?').returns(false)

    click_button 'Sign up'
    assert_equal '/', current_path

    message  = "A message with a confirmation link has been sent to your email address. "
    message << "Please follow the link to activate your account."
    assert page.has_content?(message)

    # Second sign up with same credentials
    visit new_user_registration_path
    fill_in 'Email', with: 'superman@voqal.ai'
    fill_in 'Password', with: 'great password baby!'

    click_button 'Sign up'

    expected = ["Email has already been taken"]
    assert_equal expected, all('.help--error').collect {|n| n.text}
    assert_equal '/users', current_path
  end


  test "Successful sign up" do
    FLIPPER.enable :user_registration
    visit new_user_registration_path
    fill_in 'Email', with: 'rocky@voqal.ai'
    fill_in 'Password', with: 'great password baby!'

    # TODO: Remove this as soon as possible
    User.any_instance.stubs('active_for_authentication?').returns(false)

    click_button 'Sign up'
    assert_equal '/', current_path

    message  = "A message with a confirmation link has been sent to your email address. "
    message << "Please follow the link to activate your account."
    assert page.has_content?(message)
  end


  test 'Log in failed without email and password' do
    visit new_user_session_path
    click_button 'Log in'

    assert_equal new_user_session_path, current_path
    assert page.has_content?("Invalid Email or password.")
  end


  test 'Log in failed with not confirmed email' do
    visit new_user_session_path

    fill_in 'Email', with: 'notconfirmed@voqal.ai'
    fill_in 'Password', with: 'BimBamBoom'

    click_button 'Log in'

    assert_equal new_user_session_path, current_path
    assert page.has_content?("You have to confirm your email address before continuing.")
  end


  test 'Log in failed with bad password' do
    visit new_user_session_path

    fill_in 'Email', with: 'confirmed@voqal.ai'
    fill_in 'Password', with: 'BimBam'

    click_button 'Log in'

    assert_equal new_user_session_path, current_path
    assert page.has_content?("Invalid Email or password.")
  end


  test 'Successful log in' do
    visit new_user_session_path

    fill_in 'Email', with: 'confirmed@voqal.ai'
    fill_in 'Password', with: 'BimBamBoom'

    click_button 'Log in'

    assert_equal '/', current_path
    assert page.has_content?("Signed in successfully.")
  end


  test 'Successful log in then log out' do
    visit new_user_session_path

    fill_in 'Email', with: 'confirmed@voqal.ai'
    fill_in 'Password', with: 'BimBamBoom'

    click_button 'Log in'

    assert_equal '/', current_path
    assert page.has_content?("Signed in successfully.")

    click_link 'Logout'
    assert page.has_content?("Signed out successfully.")
  end


  test "Sign in then confirm email then log in" do
    FLIPPER.enable :user_registration
    # Sign in
    visit new_user_registration_path
    fill_in 'Email', with: 'batman@voqal.ai'
    fill_in 'Password', with: 'great password baby!'

    # TODO: Remove this as soon as possible
    User.any_instance.stubs('active_for_authentication?').returns(false)

    click_button 'Sign up'
    assert_equal '/', current_path

    message  = "A message with a confirmation link has been sent to your email address. "
    message << "Please follow the link to activate your account."
    assert page.has_content?(message)

    # Visit confirmation url from email
    confirmation_token = User.find_by_email('batman@voqal.ai').confirmation_token
    visit user_confirmation_path(confirmation_token: confirmation_token)

    # TODO: Remove this as soon as possible
    User.any_instance.stubs('active_for_authentication?').returns(true)

    # Log in
    assert_equal new_user_session_path, current_path
    assert page.has_content?("Your email address has been successfully confirmed.")

    fill_in 'Email', with: 'batman@voqal.ai'
    fill_in 'Password', with: 'great password baby!'
    click_button 'Log in'

    # I'm in!
    assert_equal '/', current_path
    assert page.has_content?("Signed in successfully.")
  end


  test "Forgot password" do
    visit new_user_session_path

    click_link("Forgot your password?")

    # Forgot to fill email
    click_button 'Send me reset password instructions'
    expected = ["Email can't be blank"]
    assert_equal expected, all('.help--error').collect {|n| n.text}

    # Fill email, email is send
    fill_in 'Email', with: 'confirmed@voqal.ai'
    click_button 'Send me reset password instructions'

    message = "You will receive an email with instructions on how to reset your password in a few minutes."
    assert page.has_content?(message)
    assert_equal new_user_session_path, current_path

    # Visit url from email with reset password instructions
    token = User.find_by_email('confirmed@voqal.ai').send_reset_password_instructions
    visit edit_user_password_path(reset_password_token: token)

    fill_in 'user[password]', with: 'new password baby!'
    click_button 'Change my password'

    message = "Your password has been changed successfully. You are now signed in."
    assert page.has_content?(message)
    assert_equal '/', current_path
  end


  test "Resend confirmation instructions with confirmed email" do
    visit new_user_session_path

    click_link("Didn't receive confirmation instructions?")
    assert page.has_content? "Resend confirmation instructions"

    fill_in 'user[email]', with: 'confirmed@voqal.ai'
    click_button 'Resend confirmation instructions'

    expected = ["Email was already confirmed, please try signing in"]
    assert_equal expected, all('.help--error').collect {|n| n.text}
  end


  test "Resend confirmation instructions with not confirmed email" do
    visit new_user_session_path

    click_link("Didn't receive confirmation instructions?")
    assert page.has_content? "Resend confirmation instructions"

    fill_in 'user[email]', with: 'notconfirmed@voqal.ai'
    click_button 'Resend confirmation instructions'

    message  = "You will receive an email with instructions for how "
    message << "to confirm your email address in a few minutes."
    assert page.has_content?(message)
    assert_equal new_user_session_path, current_path
  end


  test "Lock strategy" do
    # Lock
    visit new_user_session_path

    18.times do
      fill_in 'Email', with: 'confirmed@voqal.ai'
      fill_in 'Password', with: 'BimBam'
      click_button 'Log in'
      assert page.has_content?("Invalid Email or password.")
    end

    fill_in 'Email', with: 'confirmed@voqal.ai'
    fill_in 'Password', with: 'BimBam'
    click_button 'Log in'
    assert page.has_content?("You have one more attempt before your account is locked.")

    fill_in 'Email', with: 'confirmed@voqal.ai'
    fill_in 'Password', with: 'BimBam'
    click_button 'Log in'
    assert page.has_content?("Your account is locked.")

    # Unlock
    token = User.find_by_email('confirmed@voqal.ai').send_unlock_instructions
    visit user_unlock_path(unlock_token: token)
    assert page.has_content?("Your account has been unlocked successfully. Please sign in to continue.")

    # Log in
    fill_in 'Email', with: 'confirmed@voqal.ai'
    fill_in 'Password', with: 'BimBamBoom'
    click_button 'Log in'
    assert_equal '/', current_path
    assert page.has_content?("Signed in successfully.")
  end


  test "Try to unlock when not locked" do
    visit new_user_session_path

    click_link("Didn't receive unlock instructions?")
    assert page.has_content? "Resend unlock instructions"

    fill_in 'Email', with: 'confirmed@voqal.ai'
    click_button 'Resend unlock instructions'
    expected = ["Email was not locked"]
    assert_equal expected, all('.help--error').collect {|n| n.text}
  end


  test "An invitation can be sent by administrators only" do
    visit new_user_invitation_path
    assert page.has_content? "You need to sign in or sign up before continuing."

    visit new_user_session_path
    fill_in 'Email', with: 'confirmed@voqal.ai'
    fill_in 'Password', with: 'BimBamBoom'
    click_button 'Log in'

    assert_equal '/', current_path
    assert page.has_content? "You do not have permission to access this interface."
    click_on "Logout"

    visit new_user_session_path
    fill_in 'Email', with: 'admin@voqal.ai'
    fill_in 'Password', with: 'AdminBoom'
    click_button 'Log in'

    assert_equal '/', current_path
    assert page.has_content?("Signed in successfully.")

    visit new_user_invitation_path
    fill_in 'Email', with: 'bibibubu@bibibubu.org'
    click_button 'Send invitation'
    assert page.has_content?("An invitation email has been sent to bibibubu@bibibubu.org.")
  end


  test "An invitation can be validated by someone with no session and only once" do
    u = users(:invited)
    raw_token, enc_token = Devise.token_generator.generate(User, :invitation_token)
    u.invitation_token = enc_token
    u.save
    travel_to (u.invitation_sent_at + 1.seconds)

    visit new_user_session_path
    fill_in 'Email', with: 'confirmed@voqal.ai'
    fill_in 'Password', with: 'BimBamBoom'
    click_button 'Log in'

    visit accept_user_invitation_path(invitation_token: raw_token)
    assert page.has_content? "You are already signed in."
    click_on "Logout"

    visit accept_user_invitation_path(invitation_token: raw_token)
    fill_in 'Password', with: 'The Great Magic Password'

    click_button 'Set my password'
    assert page.has_content? "Your password was set successfully. You are now signed in."

    click_on "Logout"
    visit accept_user_invitation_path(invitation_token: u.invitation_token)
    assert page.has_content? "The invitation token provided is not valid!"
  end

  test "Registration not possible if feature is disabled" do
    FLIPPER.disable :user_registration
    visit '/'
    assert !page.has_content?("Sign up")

    visit new_user_registration_path
    assert page.has_content?("User registration is temporarily disabled.")
    assert_equal '/', current_path
  end

end
