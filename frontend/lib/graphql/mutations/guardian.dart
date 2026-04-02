const createChildAccountMutation = r'''
  mutation CreateChildAccount($username: String!, $displayName: String, $birthYearMonth: String!) {
    createChildAccount(username: $username, displayName: $displayName, birthYearMonth: $birthYearMonth) {
      id
      username
      displayName
      birthYearMonth
      isChildAccount
      createdAt
    }
  }
''';

const switchToChildMutation = r'''
  mutation SwitchToChild($childId: String!) {
    switchToChild(childId: $childId) {
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

const myChildrenQuery = r'''
  query MyChildren {
    myChildren {
      id
      username
      displayName
      birthYearMonth
      isChildAccount
      createdAt
    }
  }
''';
