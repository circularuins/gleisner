const _userFields = '''
  id
  did
  email
  username
  displayName
  bio
  avatarUrl
  profileVisibility
  publicKey
  createdAt
  updatedAt
''';

const signupMutation =
    '''
  mutation Signup(\$email: String!, \$password: String!, \$username: String!, \$displayName: String, \$inviteCode: String) {
    signup(email: \$email, password: \$password, username: \$username, displayName: \$displayName, inviteCode: \$inviteCode) {
      token
      user {
        $_userFields
      }
    }
  }
''';

const loginMutation =
    '''
  mutation Login(\$email: String!, \$password: String!) {
    login(email: \$email, password: \$password) {
      token
      user {
        $_userFields
      }
    }
  }
''';

const meQuery =
    '''
  query Me {
    me {
      $_userFields
    }
  }
''';
