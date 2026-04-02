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

const createChildAccountMutation =
    '''
  mutation CreateChildAccount(\$username: String!, \$displayName: String, \$birthYearMonth: String!, \$guardianPassword: String!) {
    createChildAccount(username: \$username, displayName: \$displayName, birthYearMonth: \$birthYearMonth, guardianPassword: \$guardianPassword) {
      $_childUserFields
    }
  }
''';

const switchToChildMutation =
    '''
  mutation SwitchToChild(\$childId: String!) {
    switchToChild(childId: \$childId) {
      token
      user {
        $_childUserFields
      }
    }
  }
''';

const switchBackToGuardianMutation =
    '''
  mutation SwitchBackToGuardian {
    switchBackToGuardian {
      token
      user {
        $_childUserFields
      }
    }
  }
''';

const myChildrenQuery =
    '''
  query MyChildren {
    myChildren {
      $_childUserFields
    }
  }
''';
