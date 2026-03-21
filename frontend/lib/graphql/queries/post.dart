const postFields = '''
  id
  mediaType
  title
  body
  mediaUrl
  duration
  importance
  layoutX
  layoutY
  contentHash
  createdAt
  updatedAt
  author {
    id
    username
    displayName
    avatarUrl
  }
  track {
    id
    name
    color
  }
''';

const postsQuery =
    '''
  query Posts(\$trackId: String!) {
    posts(trackId: \$trackId) {
      $postFields
    }
  }
''';

const postQuery =
    '''
  query Post(\$id: String!) {
    post(id: \$id) {
      $postFields
    }
  }
''';
