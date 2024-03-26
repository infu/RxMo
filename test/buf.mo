import {Observable; null_func;  buffer; timerOnce; Subject; of; pipe2; pipe3; pipe4; first; map; concatAll; mergeMap; distinct; reduce; takeUntil} "../src/lib";
import Principal "mo:base/Principal";
import Timer "mo:base/Timer";
import Array "mo:base/Array";

actor Echo {

  let bump = Subject<Nat>();
  let trigger = Subject<()>();

  var count :Nat = 0;

  ignore pipe2(
      bump,
      buffer<Nat>(trigger),
  ).subscribe( {
      next = func (buf) {
          count += Array.foldRight<Nat, Nat>(buf, 0, func(x, acc) = x + acc)
      };
      complete = null_func;
  });
      
  public query func stats() : async Nat {
    return count;
  };

  public shared({caller}) func vote() : async () {
    bump.next(1);
    bump.next(2);
    trigger.next();

  } 
};
