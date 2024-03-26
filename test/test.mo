import Debug "mo:base/Debug";
import {Observable; Subject; of; pipe2; pipe3; pipe4; first; map; concatAll; mergeMap; distinct; reduce; takeUntil} "../src/lib";
import O "../src/lib";

import Principal "mo:base/Principal";
import Buffer "mo:base/Buffer";

import Time "mo:base/Time";
import Text "mo:base/Text";

import Array "mo:base/Array";
import Nat16 "mo:base/Nat16";
import Nat32 "mo:base/Nat32";
import Nat "mo:base/Nat";
import {runTest} "./util";


// ----- Basic
Debug.print("=====  Basic ( Map )");

let ob = Observable<Nat>( func (subscriber) {
    subscriber.next(3);
    subscriber.next(5);
    subscriber.next(12);
    subscriber.complete();
    subscriber.next(1231); // nothing should happen after complete
    subscriber.complete();

});

var tst_1 : Text = "";
ignore pipe3(
    ob,
    map<Nat,Nat16>( func (val) {
         Nat16.fromNat(val + 10)
    }),
    map<Nat16,Nat>( func (val)  {
         Nat16.toNat(val + 30)
    })
).subscribe( {
    next = func (v) {
        tst_1 := tst_1 # " " # debug_show(v);
        //Debug.print("next " # debug_show(v));
    };
    complete = func () {
        tst_1 := tst_1 # " | ";
        if (tst_1 == " 43 45 52 | ") tst_1 := tst_1 # "- OK ";
        Debug.print(tst_1);
    }
});

// ----- Using operators without pipe

let oz = map<Nat,Nat16>( func (val)  {
        Nat16.fromNat(val + 10 )
})(ob);

// ----- Basic
Debug.print("=====  Basic ( Distinct )");
var tst__x : Text = "";

ignore pipe2(
    of<Nat>( [1,1,2,1,3,4,4,5,5,5] ),
    distinct<Nat>( func (x) { Text.encodeUtf8(Nat.toText(x)) } ) // Has to return Blob, there are faster ways to convert Nat to Blob
    ).subscribe({
    next = func (v) {
        tst__x := tst__x # " " # debug_show(v);
    };
    complete = func () {
        tst__x := tst__x # " | ";
        if (tst__x == " 1 2 3 4 5 | ") tst__x := tst__x # "- OK ";
        Debug.print(tst__x);
    }
});


// ----- Basic
Debug.print("=====  Basic ( Of | First )");

let ob_1 = of<Nat>( [3,5,12] );

var tst__1 : Text = "";
ignore pipe2(
    ob_1,
    first<Nat>()
).subscribe({
    next = func (v) {
        tst__1 := tst__1 # " " # debug_show(v);
    };
    complete = func () {
        tst__1 := tst__1 # " | ";
        if (tst__1 == " 3 | ") tst__1 := tst__1 # "- OK ";
        Debug.print(tst__1);
    }
});


// ----- Higher-order observables (Observable of observables)
Debug.print("=====  Higher-order observables ( Observable | ConcatAll )");

var tst_2 : Text = "";

let ob2 = Observable<O.Obs<Nat>>( func (subscriber) {

    subscriber.next(of<Nat>([1,2,3]));

    subscriber.next(of<Nat>([4,5,6]));

    subscriber.next(of<Nat>([7,8,9]));

    subscriber.complete();
});

ignore pipe2(
    ob2,
    concatAll<Nat>()

).subscribe( {
    next = func (v) {
        tst_2 := tst_2 # " " # debug_show(v);
    };
    complete = func () {
        tst_2 := tst_2 # " | ";
        if (tst_2 == " 1 2 3 4 5 6 7 8 9 | ") tst_2 := tst_2 # "- OK ";
        Debug.print(tst_2);
    }
});

// ----- Higher-order observables (Observable of observables)
Debug.print("===== Higher-order observables ( Subject | ConcatAll )");

var tst_3 : Text = "";

let ob3 = Observable<O.Obs<Nat>>( func (subscriber) {

    let subj1 = Subject<Nat>();
    subscriber.next(subj1);
    
    let subj2 = Subject<Nat>();
    subscriber.next(subj2);

    let subj3 = Subject<Nat>();
    subscriber.next(subj3);

    subj1.next(1);//

    subj2.next(4);

    subj3.next(7);//3

    subj1.next(2);//

    subj2.next(5);

    subj1.next(3);//

    subj1.complete(); // -- All other than subj1 subscriptions were ignored until this point

    
    subj3.next(8);//3   // -- Here it's determined if subj3 or subj2 will be next in line (whoever is first is added)
    subj3.next(9);//3
    subj3.complete();//3 // -- All other than subj3 ignored


    subj2.next(6);//
    subj2.complete();   // -- All other than subj2 ignored

    subscriber.complete();
});

ignore pipe2(
    ob3,
    concatAll<Nat>()
 
).subscribe( {
    next = func (v) {
         tst_3 := tst_3 # " " # debug_show(v);
    };
    complete = func () {
        tst_3 := tst_3 # " | ";
        if (tst_3 == " 1 2 3 8 9 6 | ") tst_3 := tst_3 # "- OK ";
        Debug.print(tst_3);
    }
});


// ----- Higher-order observables (Observable of observables)
Debug.print("===== Higher-order observables ( MergeMap )");
 


var tst_4 : Text = "";

ignore pipe2(
    of<Text>(["A","B","C"]),
    mergeMap<Text,Text>( func(x) { 
        pipe2(
            of<Nat>([1,2,3,4,5,6]),
            map<Nat, Text>( func (i) {
                x # debug_show(i);
            })
        );
    }, 1)
).subscribe( {
    next = func (v) {
         tst_4 := tst_4 # " " # v;
    };
    complete = func () {
        tst_4 := tst_4 # " | ";
        if (tst_4 == " A1 A2 A3 A4 A5 A6 B1 B2 B3 B4 B5 B6 C1 C2 C3 C4 C5 C6 | ") tst_4 := tst_4 # "- OK ";
        Debug.print(tst_4);
    }
});

// -----  Distinct


Debug.print("===== Distinct ");

type CustomThing = {
    caller: Principal;
    data: Nat;
};

runTest<CustomThing>(
    pipe2(
    of<CustomThing>([
    {
        caller = Principal.fromText("aaaaa-aa");
        data=5
    }, {
        caller=Principal.fromText("aaaaa-aa");
        data=9
    }, {
        caller=Principal.fromText("oqtwf-pmlo4-pgvqe-wg4xh-qkrlc-g6t5c-ga6tt-5cyi7-ih2rw-t423u-oae");
        data=12
    }
    ]),
    distinct<CustomThing>(func (x) { Principal.toBlob(x.caller) })
),
func (x) {debug_show(x)},
" {caller = aaaaa-aa; data = 5} {caller = oqtwf-pmlo4-pgvqe-wg4xh-qkrlc-g6t5c-ga6tt-5cyi7-ih2rw-t423u-oae; data = 12} | "); // result



// -----  Reduce


Debug.print("===== Reduce ");

type Vote = {
    #yes;
    #no
};
type VoteCounter = {
    accept: Nat;
    reject: Nat;
};

runTest<VoteCounter>(
    pipe2(
    of<Vote>([ #yes, #yes, #yes, #no, #no, #yes, #no, #yes, #yes ]),
    reduce<Vote, VoteCounter>(func({accept; reject}, vote) { // count votes
        switch(vote) {
            case (#yes) ({accept = accept + 1; reject});
            case (#no) ({accept; reject = reject + 1});
        }
    }, { accept = 0; reject = 0}), // default
    ),
    func (x) {debug_show(x)},
    " {accept = 6; reject = 3} | " // result
);


// -----  Reduce


Debug.print("===== takeUntil ");


let main = Subject<Nat>();
let trigger = Subject<Bool>();

runTest<Nat>(pipe2(
    main,
    takeUntil<Nat, Bool>(trigger)
),
func (x) {debug_show(x)},
" 1 2 3 4 | " // result
);

main.next(1);
main.next(2);
main.next(3);
main.next(4);
trigger.next(true); // this will trigger takeUntil and complete observer main, no more values will go thru
main.next(5); // nothing should happen
main.next(6); // nothing should happen
trigger.next(true); // nothing should happen
main.complete(); // again nothing should happen





Debug.print("\n--END--");


