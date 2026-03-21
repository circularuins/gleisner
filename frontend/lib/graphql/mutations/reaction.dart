const toggleReactionMutation = '''
  mutation ToggleReaction(\$postId: String!, \$emoji: String!) {
    toggleReaction(postId: \$postId, emoji: \$emoji) {
      id
      emoji
    }
  }
''';
