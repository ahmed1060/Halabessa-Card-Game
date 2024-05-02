import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: Text('Halabessa')),
        body: CardStack(),
      ),
    );
  }
}

class CardStack extends StatefulWidget {
  @override
  _CardStackState createState() => _CardStackState();
}

class _CardStackState extends State<CardStack> {
  final List<CardInfo> cards = [
    CardInfo(value: 'K', suit: Suit.hearts),
    CardInfo(value: 'A', suit: Suit.hearts),
    CardInfo(value: 'J', suit: Suit.hearts),
    CardInfo(value: '7', suit: Suit.hearts),
  ];

  double _baseLeftOffset(int index, double cardWidth, double cardSpacing, double sizeWidth) {
    final totalCardWidth = cardWidth * cards.length;
    final totalSpacingWidth = cardSpacing * (cards.length - 1);
    final totalWidth = totalCardWidth + totalSpacingWidth;
    return (sizeWidth - totalWidth) / 2 + index * (cardWidth + cardSpacing);
  }

  double _baseTopOffset(double cardWidth, double sizeHeight) {
    return sizeHeight * 0.75 - cardWidth * 0.7;
  }

  @override
  Widget build(BuildContext context) {
    var size = MediaQuery.of(context).size;
    final cardWidth = size.width * 0.07;
    final cardSpacing = size.width * 0.01;
    final cardHeight = cardWidth * 1.4;

    return Stack(
      children: List.generate(cards.length, (index) {
        final baseLeftOffset = _baseLeftOffset(index, cardWidth, cardSpacing, size.width);
        final baseTopOffset = _baseTopOffset(cardWidth, size.height);

        return Positioned(
          left: baseLeftOffset,
          top: baseTopOffset,
          child: CardWidget(
            card: cards[index],
            onTap: () => _handleCardTap(cards[index]),
          ),
        );
      }),
    );
  }

  void _handleCardTap(CardInfo card) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Card Tapped"),
          content: Text("You tapped on ${card.value} of ${card.suit}."),
          actions: <Widget>[
            TextButton(
              child: Text("OK"),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }
}

enum Suit { hearts, diamonds, clubs, spades }

class CardInfo {
  final String value;
  final Suit suit;

  CardInfo({required this.value, required this.suit});
}

class CardWidget extends StatelessWidget {
  final CardInfo card;
  final VoidCallback onTap;

  const CardWidget({required this.card, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cardWidth = MediaQuery.of(context).size.width * 0.07;
    final cardHeight = cardWidth * 1.4;

    return InkWell(
      onTap: onTap,
      child: Container(
        width: cardWidth,
        height: cardHeight,
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.black),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(card.value, style: TextStyle(fontSize: cardWidth * 0.2)),
              SizedBox(height: 8),
              Text(card.suit.name, style: TextStyle(fontSize: cardWidth * 0.15)),
            ],
          ),
        ),
),
);
}
}