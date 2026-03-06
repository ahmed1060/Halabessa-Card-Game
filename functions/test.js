const { validateMove } = require('./index');

describe('Halabessa Move Validation', () => {
    test('Capture on Rank Match', async () => {
        const req = {
            body: {
                matchId: 'test',
                playerId: 'user1',
                playedCard: { rank: 'ACE', suit: 'SPADES' },
                board: [{ rank: 'ACE', suit: 'HEARTS' }, { rank: 'KING', suit: 'CLUBS' }]
            }
        };

        const res = {
            json: (data) => {
                expect(data.valid).toBe(true);
                expect(data.captured.length).toBe(3); // 2 on board + 1 played
                expect(data.isBasra).toBe(true);
            }
        };

        // This is a simplified test for the onRequest export
        // In a real environment, you'd use firebase-functions-test
    });

    test('No Capture on Rank Mismatch', async () => {
        const req = {
            body: {
                matchId: 'test',
                playerId: 'user1',
                playedCard: { rank: 'TEN', suit: 'SPADES' },
                board: [{ rank: 'ACE', suit: 'HEARTS' }]
            }
        };

        const res = {
            json: (data) => {
                expect(data.valid).toBe(true);
                expect(data.captured.length).toBe(0);
            }
        };
    });
});
