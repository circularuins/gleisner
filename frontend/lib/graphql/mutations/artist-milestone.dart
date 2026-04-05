const createArtistMilestoneMutation = '''
  mutation CreateArtistMilestone(
    \$category: MilestoneCategory!,
    \$title: String!,
    \$description: String,
    \$date: String!,
    \$position: Int
  ) {
    createArtistMilestone(
      category: \$category,
      title: \$title,
      description: \$description,
      date: \$date,
      position: \$position
    ) {
      id category title description date position createdAt
    }
  }
''';

const updateArtistMilestoneMutation = '''
  mutation UpdateArtistMilestone(
    \$id: String!,
    \$category: MilestoneCategory,
    \$title: String,
    \$description: String,
    \$date: String,
    \$position: Int
  ) {
    updateArtistMilestone(
      id: \$id,
      category: \$category,
      title: \$title,
      description: \$description,
      date: \$date,
      position: \$position
    ) {
      id category title description date position
    }
  }
''';

const deleteArtistMilestoneMutation = '''
  mutation DeleteArtistMilestone(\$id: String!) {
    deleteArtistMilestone(id: \$id) {
      id
    }
  }
''';

const toggleMilestoneReactionMutation = '''
  mutation ToggleMilestoneReaction(\$milestoneId: String!, \$emoji: String!) {
    toggleMilestoneReaction(milestoneId: \$milestoneId, emoji: \$emoji) {
      id
      emoji
    }
  }
''';
