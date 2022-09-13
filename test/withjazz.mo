import Debug "mo:base/Debug";
import {Observable; Subject; of; pipe2; pipe3; pipe4; first; map; concatAll; mergeMap; distinct; reduce; takeUntil} "../src/observable";
import O "../src/observable";

import Principal "mo:base/Principal";
import Buffer "mo:base/Buffer";

import Time "mo:base/Time";
import Text "mo:base/Text";

import Array "mo:base/Array";
import Nat16 "mo:base/Nat16";
import Nat32 "mo:base/Nat32";
import Nat "mo:base/Nat";
import Jazz "../../jazz/src/jazz";
import {timerOnce} "../../jazz/src/RxJazz";

import {runTest} "./util";

Debug.print("--BEGIN withjazz --");


let jazz = Jazz.Jazz();

jazz.mockTime := ?1;



type Vote = {
    caller : Principal;
    vote : {#yes; #no};
};
type VoteCount = {
    accept : Nat;
    reject : Nat;
};

let proposal = Subject<Vote>();

pipe4(
    proposal,
    distinct<Vote>(func (x) { Principal.toBlob(x.caller) }), // don't let someone vote twice with the same principal
    takeUntil<Vote, Bool>(timerOnce(jazz, 60)), // Take votes until 60 seconds pass
    reduce<Vote, VoteCount>(func({accept; reject}, {vote}) { // count votes
        switch(vote) {
            case (#yes) ({accept = accept + 1; reject});
            case (#no) ({accept; reject = reject + 1});
        }
    }, { accept = 0; reject = 0}), // default
    ).subscribe({
        next = func (votes) {
            Debug.print(debug_show(votes))
        };
        complete = func () {}
    });

proposal.next({
    caller = Principal.fromText("aaaaa-aa");
    vote = #yes
});



jazz.mockTime := ?70;
await jazz.heartbeat();

proposal.next({ // this shouldn't pass the `distinct` filter
    caller = Principal.fromText("aaaaa-aa");
    vote = #no
});

proposal.next({
    caller = Principal.fromText("oqtwf-pmlo4-pgvqe-wg4xh-qkrlc-g6t5c-ga6tt-5cyi7-ih2rw-t423u-oae");
    vote = #yes
});

proposal.complete();


Debug.print("--END withjazz--");

