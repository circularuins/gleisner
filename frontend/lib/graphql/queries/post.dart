const postsQuery = r'''
  query Posts($trackId: String!) {
    posts(trackId: $trackId) {
      id
      mediaType
      title
      body
      mediaUrl
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
    }
  }
''';

const postQuery = r'''
  query Post($id: String!) {
    post(id: $id) {
      id
      mediaType
      title
      body
      mediaUrl
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
    }
  }
''';
