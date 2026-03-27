const createGenreMutation = r'''
  mutation CreateGenre($name: String!) {
    createGenre(name: $name) {
      id
      name
    }
  }
''';

const addArtistGenreMutation = r'''
  mutation AddArtistGenre($genreId: String!, $position: Int) {
    addArtistGenre(genreId: $genreId, position: $position) {
      position
      genre {
        id
        name
      }
    }
  }
''';

const removeArtistGenreMutation = r'''
  mutation RemoveArtistGenre($genreId: String!) {
    removeArtistGenre(genreId: $genreId) {
      position
      genre {
        id
        name
      }
    }
  }
''';
