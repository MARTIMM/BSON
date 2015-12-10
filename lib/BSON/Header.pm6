use v6;

use BSON::Document;

package BSON {


  #-----------------------------------------------------------------------------
  # Constants. See http://www.mongodb.org/display/DOCS/Mongo+Wire+Protocol#MongoWireProtocol-RequestOpcodes
  #
  constant C-OP-REPLY           = 1;    # Reply to a client request.responseTo is set
  constant C-OP-MSG             = 1000; # generic msg command followed by a string. deprecated
  constant C-OP-UPDATE          = 2001; # update document
  constant C-OP-INSERT          = 2002; # insert new document
  constant C-RESERVED           = 2003; # formerly used for OP_GET_BY_OID
  constant C-OP-QUERY           = 2004; # query a collection
  constant C-OP-GET-MORE        = 2005; # Get more data from a query. See Cursors
  constant C-OP-DELETE          = 2006; # Delete documents
  constant C-OP-KILL-CURSORS    = 2007; # Tell database client is done with a cursor

  #-----------------------------------------------------------------------------
  # Query flags
  #
  constant C-QF-TAILABLECURSOR  = 0x02; # corresponds to TailableCursor. Tailable means cursor is not closed when the last data is retrieved. Rather, the cursor marks the final object\u2019s position. You can resume using the cursor later, from where it was located, if more data were received. Like any \u201clatent cursor\u201d, the cursor may become invalid at some point (CursorNotFound) \u2013 for example if the final object it references were deleted.
  constant C-QF-SLAVEOK         = 0x04; # corresponds to SlaveOk.Allow query of replica slave. Normally these return an error except for namespace \u201clocal\u201d.
  constant C-QF-OPLOGREPLAY     = 0x08; # corresponds to OplogReplay. Internal replication use only - driver should not set.
  constant C-QF-NOCURSORTIMOUT  = 0x10; # corresponds to NoCursorTimeout. The server normally times out idle cursors after an inactivity period (10 minutes) to prevent excess memory use. Set this option to prevent that.
  constant C-QF-AWAITDATA       = 0x20; # corresponds to AwaitData. Use with TailableCursor. If we are at the end of the data, block for a while rather than returning no data. After a timeout period, we do return as normal.
  constant C-QF-EXHAUST         = 0x40; # corresponds to Exhaust. Stream the data down full blast in multiple \u201cmore\u201d packages, on the assumption that the client will fully read all data queried. Faster when you are pulling a lot of data and know you want to pull it all down. Note: the client is not allowed to not read all the data unless it closes the connection.
  constant C-QF-PORTAIL         = 0x80; # corresponds to Partial. Get partial results from a mongos if some shards are down (instead of throwing an error)

  #-----------------------------------------------------------------------------
  # Response flags
  #
  constant C-RF-CursorNotFound  = 0x01; # corresponds to CursorNotFound. Is set when getMore is called but the cursor id is not valid at the server. Returned with zero results.
  constant C-RF-QueryFailure    = 0x02; # corresponds to QueryFailure. Is set when query failed. Results consist of one document containing an \u201c$err\u201d field describing the failure.
  constant C-RF-ShardConfigStale= 0x04; # corresponds to ShardConfigStale. Drivers should ignore this. Only mongos will ever see this set, in which case, it needs to update config from the server.
  constant C-RF-AwaitCapable    = 0x08; # corresponds to AwaitCapable. Is set when the server supports the AwaitData Query option. If it doesn\u2019t, a client should sleep a little between getMore\u2019s of a Tailable cursor. Mongod version 1.6 supports AwaitData and thus always sets AwaitCapable.


  role Header {

    # These variables must be shared between role Header objects.
    #
    my Bool $debug = False;
    my Int $request_id = 0;

    #---------------------------------------------------------------------------
    # Needed call because of error:
    # Cannot call AUTOGEN(BSON::Document+{BSON::Header}: ); none of these signatures match:
    #     (BSON::Document $: List :$pairs!, *%_)
    #     (BSON::Document $: Buf :$buf!, *%_)
    #   in block <unit> at ...
    # The signatures are from BUILD submethods defined in BSON::Document
    #
    multi submethod BUILD ( ) {

    }

    #---------------------------------------------------------------------------
    #
    method encode-message-header ( Int $buffer-size, Int $op-code --> Buf ) {

      # http://www.mongodb.org/display/DOCS/Mongo+Wire+Protocol#MongoWireProtocol-StandardMessageHeader
      # struct MsgHeader
      #
      my Buf $msg-header = [~]

        # int32 messageLength
        # total message size, including this, 4 * 4 are 4 int32's
        #
        encode-int32($buffer-size + 4 * 4),

        # int32 requestID
        # identifier for this message, at start 0, visible across wire ojects
        #
        encode-int32($request_id++),

        # int32 responseTo
        # requestID from the original request, no response so 0
        # (used in reponses from db)
        #
        encode-int32(0),

        # int32 opCode
        # request type, code from caller is a choice from constants
        #
        encode-int32($op-code);

      return $msg-header;
    }

    #---------------------------------------------------------------------------
    #
    method decode-message-header ( Buf $b, $index is rw --> BSON::Document ) {

      # http://www.mongodb.org/display/DOCS/Mongo+Wire+Protocol#MongoWireProtocol-StandardMessageHeader
      # struct MsgHeader
      #
      my BSON::Document $msg-header .= new: (

        # int32 messageLength
        # total message size, including this
        #
        message-length  => decode-int32( $b, $index),

        # int32 requestID
        # identifier for this message
        #
        request-id      => decode-int32( $b, $index + BSON::C-INT32-SIZE),

        # int32 responseTo
        # requestID from the original request
        # (used in reponses from db)
        #
        response-to     => decode-int32( $b, $index + 2 * BSON::C-INT32-SIZE),

        # int32 opCode
        # request type
        #
        op-code         => decode-int32( $b, $index + 3 * BSON::C-INT32-SIZE)
      );

      # the only allowed message returned from database is C-OP-REPLY
      #
#      die [~] 'Unexpected OP_code (', $msg-header<op_code>, ')'
#         unless $msg-header<op_code> == C-OP-REPLY;

      $index += 4 * BSON::C-INT32-SIZE;
      return $msg-header;
    }

    #---------------------------------------------------------------------------
    #
    multi method encode-query (
      Str:D $full-collection-name, BSON::Document $projection?,
      Int :$flags = 0, Int :$number-to-skip = 0, Int :$number-to-return = 0
      --> Buf
    ) {
      # http://www.mongodb.org/display/DOCS/Mongo+Wire+Protocol#MongoWireProtocol-OPQUERY

      my Buf $query-buffer = [~]

        # int32 flags
        # bit vector of query options
        #
        encode-int32($flags),

        # cstring fullCollectionName
        # "dbname.collectionname"
        #
        encode-cstring($full-collection-name),

        # int32 numberToSkip
        # number of documents to skip
        #
        encode-int32($number-to-skip),

        # int32 numberToReturn
        # number of documents to return
        # in the first C-OP-REPLY batch
        #
        encode-int32($number-to-return),

        # document query
        # query object
        #
        self.encode;


      # [ document  returnFieldSelector; ]
      # Optional. Selector indicating the fields to return
      #
      if ? $projection {
        $query-buffer ~= $projection.encode;
      }

      # MsgHeader header
      # standard message header
      #
      return self.encode-message-header( $query-buffer.elems, BSON::C-OP-QUERY)
             ~ $query-buffer;

#`{{
      # send message and wait for response
      #
      my Buf $B-OP-REPLY = $collection.database.connection._send(
        $msg-header ~ $query-buffer, True
      );

      # parse response
      #
      my BSON::Document $reply-document = self!OP-REPLY($B-OP-REPLY);

      if $debug {
        say 'OP-QUERY:', $reply-document.perl;
      }

      # TODO check if requestID matches responseTo

      # return response back to cursor
      #
      return $reply-document;
}}
    }

    #---------------------------------------------------------------------------
    #
    method decode-reply ( Buf $b --> BSON::Document ) {

      # http://www.mongodb.org/display/DOCS/Mongo+Wire+Protocol#MongoWireProtocol-OPREPLY
      # Because the decoding is not started via self.decode() $!index in BSON must
      # be initialized explicitly. There may not be another decode() started in the
      # mean time using this object because this attribute will be disturbed.
      #
      my $index = 0;

      my BSON::Document $reply-document .= new: (

        # MsgHeader header
        # standard message header
        #
        message-header => self.decode-message-header( $b, $index),

        # int32 responseFlags
        # bit vector
        #
        response-flags  => decode-int32( $b, $index),

        # int64 cursorID
        # cursor id if client needs to do get more's
        # TODO big integers are not yet implemented in Rakudo
        # so cursor is build using raw Buf
        #
        cursor-id       => Buf.new(
          $b[($index + BSON::C-INT32-SIZE) .. ($index + BSON::C-INT32-SIZE + 7)]
        ),

        # int32 startingFrom
        # where in the cursor this reply is starting
        #
        starting-from   => decode-int32( $b, $index + BSON::C-INT32-SIZE + 8),

        # int32 numberReturned
        # number of documents in the reply
        #
        number-returned => decode-int32( $b, $index + 2 * BSON::C-INT32-SIZE + 8),

        # document* documents
        # documents
        #
        documents => [ ],
      );

      $index += 3 * BSON::C-INT32-SIZE + 8;

say "Repl doc: ", $reply-document<number-returned>;

      # Extract documents from message.
      #
      for ^$reply-document<number-returned> {
        my $doc-size = decode-int32( $b, $index);
say "I: $index, $doc-size";
#        $index += 4;
        my BSON::Document $document .= new(
          Buf.new($b[$index ..^ ($index + $doc-size)])
        );
        $index += $doc-size;
        $reply-document<documents>.push($document);
      }

      $index += 3 * BSON::C-INT32-SIZE + 8;
say "B: $index, ", $b.elems;

      # Every response byte must be consumed
      #
      die 'Unexpected bytes at the end of response' if $index < $b.elems;

      return $reply-document;
    }
  }
}
