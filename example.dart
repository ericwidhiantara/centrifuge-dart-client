import 'dart:convert';
import 'dart:io';

import 'package:centrifuge/centrifuge.dart' as centrifuge;

void main() async {
  final url = 'ws://localhost:8000/connection/websocket';
  final channel = 'room:a4e38d9b-9fa5-4ff0-b7df-df8b40198861';
  // generate user JWT token for user "dart":
  // ./centrifugo gentoken --user dart
  final userJwtToken =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJkYXJ0IiwiZXhwIjoxNzE4MDMyNDc4LCJpYXQiOjE3MTc0Mjc2Nzh9.mmH1P6-gwtP8bhiIK7PbXhTfrNamef9zv4Giho3U3UY';
  // generate subscription JWT token for user "dart" and channel "chat:index":
  // ./centrifugo gensubtoken --user dart --channel chat:index
  final subscriptionJwtToken =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJkYXJ0IiwiZXhwIjoxNzE4MDkzMzE1LCJpYXQiOjE3MTc0ODg1MTUsImNoYW5uZWwiOiJyb29tOmE0ZTM4ZDliLTlmYTUtNGZmMC1iN2RmLWRmOGI0MDE5ODg2MSJ9.jcFnj1m7hNdSEXaOQSXpyquPzLquYmu9j0twammi4_U';

  final onEvent = (dynamic event) {
    print('client> $event');
  };

  try {
    final client = centrifuge.createClient(
      url,
      centrifuge.ClientConfig(
        token: userJwtToken,
        // Headers are only supported on platforms that support dart:io
        headers: <String, dynamic>{'X-Example-Header': 'example'},
      ),
    );

    // State changes.
    client.connecting.listen(onEvent);
    client.connected.listen(onEvent);
    client.disconnected.listen(onEvent);

    // Handle async errors.
    client.error.listen(onEvent);

    // Server-side subscriptions.
    client.subscribing.listen(onEvent);
    client.subscribed.listen(onEvent);
    client.unsubscribed.listen(onEvent);
    client.publication.listen(onEvent);
    client.join.listen(
      (event) {
        print('Client joined channel: $event');
      },
    );
    client.leave.listen(onEvent);

    final subscription = client.newSubscription(
      channel,
      // centrifuge.SubscriptionConfig(
      //   token: subscriptionJwtToken,
      //   getToken: (centrifuge.SubscriptionTokenEvent event) {
      //     return Future.value('');
      //   },
      // ),
    );

    final onSubscriptionEvent = (dynamic event) async {
      print('subscription $channel> $event');
    };

    // State changes.
    subscription.subscribing.listen(onSubscriptionEvent);
    subscription.subscribed.listen(onSubscriptionEvent);
    subscription.unsubscribed.listen(onSubscriptionEvent);

    // Messages.
    subscription.publication.listen(onSubscriptionEvent);
    subscription.join.listen((event) {
      print('Client joined channel: $event');
    });
    subscription.leave.listen((event) {
      print('Client left channel: $event');
    });

    // Handle subscription async errors.
    subscription.error.listen(onSubscriptionEvent);

    await subscription.subscribe();

    await client.connect();

    final handler = _handleUserInput(client, subscription);

    await for (List<int> codeUnit in stdin) {
      final message = utf8.decode(codeUnit).trim();
      handler(message);
    }
  } catch (ex) {
    print(ex);
  }
}

Function(String) _handleUserInput(
    centrifuge.Client client, centrifuge.Subscription subscription) {
  return (String message) async {
    switch (message) {
      case '#subscribe':
        await subscription.subscribe();
        break;
      case '#unsubscribe':
        await subscription.unsubscribe();
        break;
      case '#remove':
        await client.removeSubscription(subscription);
        break;
      case '#connect':
        await client.connect();
        break;
      case '#rpc':
        final request = jsonEncode({'param': 'test'});
        final data = utf8.encode(request);
        final result = await client.rpc('test', data);
        print('RPC result: ' + utf8.decode(result.data));
        break;
      case '#presence':
        final result = await subscription.presence();
        print(result);
        break;
      case '#presenceStats':
        final result = await subscription.presenceStats();
        print(result);
        break;
      case '#history':
        final result = await subscription.history(limit: 10);
        print('History num publications: ' +
            result.publications.length.toString());
        print('Stream top position: ' +
            result.offset.toString() +
            ', epoch: ' +
            result.epoch);
        break;
      case '#disconnect':
        await client.disconnect();
        break;
      default:
        final output = jsonEncode({'input': message});
        final data = utf8.encode(output);
        try {
          await subscription.publish(data);
        } catch (ex) {
          print("can't publish: $ex");
        }
        break;
    }
    return;
  };
}
