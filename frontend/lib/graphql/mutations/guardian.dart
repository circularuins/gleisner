const _childUserFields = '''
  id
  did
  email
  username
  displayName
  bio
  avatarUrl
  profileVisibility
  publicKey
  birthYearMonth
  isChildAccount
  createdAt
  updatedAt
''';

const createChildAccountMutation = '''
  mutation CreateChildAccount(\$username: String!, \$displayName: String, \$birthYearMonth: String!) {
    createChildAccount(username: \$username, displayName: \$displayName, birthYearMonth: \$birthYearMonth) {
      $_childUserFields
    }
  }
''';

const switchToChildMutation = '''
  mutation SwitchToChild(\$childId: String!) {
    switchToChild(childId: \$childId) {
      token
      user {
        $_childUserFields
      }
    }
  }
''';

const switchBackToGuardianMutation = r'''
  mutation SwitchBackToGuardian {
    switchBackToGuardian {
      token
      user {
        id
        did
        email
        username
        displayName
        bio
        avatarUrl
        profileVisibility
        publicKey
        birthYearMonth
        isChildAccount
        createdAt
        updatedAt
      }
    }
  }
''';

const myChildrenQuery = '''
  query MyChildren {
    myChildren {
      $_childUserFields
    }
  }
''';
