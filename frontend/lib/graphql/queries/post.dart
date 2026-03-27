const postFields = '''
  id
  mediaType
  title
  body
  mediaUrl
  duration
  importance
  visibility
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
  reactionCounts {
    emoji
    count
  }
  myReactions
  outgoingConnections {
    id
    sourceId
    targetId
    connectionType
  }
  incomingConnections {
    id
    sourceId
    targetId
    connectionType
  }
  constellation {
    id
    name
    anchorPostId
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
