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
    \$mediaUrls: [String!],
    \$thumbnailUrl: String,
    \$duration: Int,
    \$importance: Float,
    \$visibility: String,
    \$eventAt: String,
    \$articleGenre: ArticleGenre,
    \$externalPublish: Boolean
  ) {
    createPost(
      trackId: \$trackId,
      mediaType: \$mediaType,
      title: \$title,
      body: \$body,
      bodyFormat: \$bodyFormat,
      mediaUrl: \$mediaUrl,
      mediaUrls: \$mediaUrls,
      thumbnailUrl: \$thumbnailUrl,
      duration: \$duration,
      importance: \$importance,
      visibility: \$visibility,
      eventAt: \$eventAt,
      articleGenre: \$articleGenre,
      externalPublish: \$externalPublish
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
    \$mediaUrls: [String!],
    \$thumbnailUrl: String,
    \$duration: Int,
    \$importance: Float,
    \$visibility: String,
    \$eventAt: String,
    \$articleGenre: ArticleGenre,
    \$clearArticleGenre: Boolean,
    \$externalPublish: Boolean
  ) {
    updatePost(
      id: \$id,
      trackId: \$trackId,
      title: \$title,
      body: \$body,
      bodyFormat: \$bodyFormat,
      mediaUrl: \$mediaUrl,
      mediaUrls: \$mediaUrls,
      thumbnailUrl: \$thumbnailUrl,
      duration: \$duration,
      importance: \$importance,
      visibility: \$visibility,
      eventAt: \$eventAt,
      articleGenre: \$articleGenre,
      clearArticleGenre: \$clearArticleGenre,
      externalPublish: \$externalPublish
    ) {
      $postFields
    }
  }
''';

const deletePostMutation = r'''
  mutation DeletePost($id: String!) {
    deletePost(id: $id) {
      id
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
