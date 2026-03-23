const createConnectionMutation = '''
  mutation CreateConnection(
    \$sourceId: String!,
    \$targetId: String!,
    \$connectionType: ConnectionType!
  ) {
    createConnection(
      sourceId: \$sourceId,
      targetId: \$targetId,
      connectionType: \$connectionType
    ) {
      id
      sourceId
      targetId
      connectionType
    }
  }
''';

const deleteConnectionMutation = '''
  mutation DeleteConnection(\$id: String!) {
    deleteConnection(id: \$id) {
      id
    }
  }
''';
