import '../queries/post.dart';

const createPostMutation =
    '''
  mutation CreatePost(
    \$trackId: String!,
    \$mediaType: MediaType!,
    \$title: String,
    \$body: String,
    \$bodyFormat: String,
    \$mediaUrl: String,
    \$thumbnailUrl: String,
    \$duration: Int,
    \$importance: Float,
    \$visibility: String,
    \$eventAt: String
  ) {
    createPost(
      trackId: \$trackId,
      mediaType: \$mediaType,
      title: \$title,
      body: \$body,
      bodyFormat: \$bodyFormat,
      mediaUrl: \$mediaUrl,
      thumbnailUrl: \$thumbnailUrl,
      duration: \$duration,
      importance: \$importance,
      visibility: \$visibility,
      eventAt: \$eventAt
    ) {
      $postFields
    }
  }
''';

const updatePostMutation =
    '''
  mutation UpdatePost(
    \$id: String!,
    \$trackId: String,
    \$title: String,
    \$body: String,
    \$bodyFormat: String,
    \$mediaUrl: String,
    \$thumbnailUrl: String,
    \$duration: Int,
    \$importance: Float,
    \$visibility: String,
    \$eventAt: String
  ) {
    updatePost(
      id: \$id,
      trackId: \$trackId,
      title: \$title,
      body: \$body,
      bodyFormat: \$bodyFormat,
      mediaUrl: \$mediaUrl,
      thumbnailUrl: \$thumbnailUrl,
      duration: \$duration,
      importance: \$importance,
      visibility: \$visibility,
      eventAt: \$eventAt
    ) {
      $postFields
    }
  }
''';

const fetchOgpMutation =
    '''
  mutation FetchOgp(\$postId: String!) {
    fetchOgp(postId: \$postId) {
      $postFields
    }
  }
''';
