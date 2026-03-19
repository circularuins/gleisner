const signupMutation = r'''
  mutation Signup($email: String!, $password: String!, $username: String!) {
    signup(email: $email, password: $password, username: $username) {
      token
      user {
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
      }
    }
  }
''';

const loginMutation = r'''
  mutation Login($email: String!, $password: String!) {
    login(email: $email, password: $password) {
      token
      user {
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
      }
    }
  }
''';

const meQuery = r'''
  query Me {
    me {
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
    }
  }
''';
