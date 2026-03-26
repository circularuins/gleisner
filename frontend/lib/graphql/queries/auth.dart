const _userFields = '''
  id
  did
  email
  username
  displayName
  bio
  avatarUrl
  publicKey
  createdAt
  updatedAt
''';

const signupMutation =
    '''
  mutation Signup(\$email: String!, \$password: String!, \$username: String!, \$displayName: String) {
    signup(email: \$email, password: \$password, username: \$username, displayName: \$displayName) {
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
