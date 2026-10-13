# Dealer cut rule

The dealer cuts and deals. With four seats in turn order 1 → 2 → 3 → 4,
dealer 1 cuts and player 2 starts playing. First-play order is unchanged.

Only the dealer sees the cut action. Online validation rejects another player's
manual cut or an attempt to proxy the dealer. Offline engine validation follows
the same rule. Automatic cut scheduling uses the dealer's identity: bot dealer
after 1 second online, human dealer at the existing preparation timeout (15
seconds if the gameplay timer is disabled). No deck-reveal/deal delays change.

Regression checks cover all four dealer seats, rejected previous-seat cuts,
unmodified decks on rejection, first-play order, authenticated command ownership,
deadline boundaries, and portrait/landscape cut controls.
