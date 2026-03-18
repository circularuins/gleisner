export function generateDid(userId: string): string {
  return `did:web:gleisner.app:u:${userId}`;
}
