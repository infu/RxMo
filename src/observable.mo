import List "mo:base/List";
import Buffer "mo:base/Buffer";
import TrieMap "mo:base/TrieMap";
import TrieSet "mo:base/TrieSet";
import Hash "mo:base/Hash";
import Blob "mo:base/Blob";
import Debug "mo:base/Debug";
import Timer "mo:base/Timer";
import Array "mo:base/Array";

module {


  public type Operator<X,Y> = (Obs<X>) -> (Obs<Y>);

  // Buffers the source Observable values until closingNotifier emits.
  public func buffer<X>( closingNotifier: Obs<()> ) : (Obs<X>) -> (Obs<[X]>) {

    return func ( x : Obs<X> ) {
        Observable<[X]>( func (subscriber) {

          var buffer : List.List<X> = List.nil();
          
          ignore closingNotifier.subscribe({
              next = func(z:()) {
                subscriber.next( Array.reverse(List.toArray(buffer)) );
                buffer := List.nil();
              };
              complete = subscriber.complete
          });
          
          ignore x.subscribe({
            next = func(v) {
                buffer := List.push<X>(v, buffer);
            };
            complete = subscriber.complete
          })
        });
      }
  };


  // Recurring timer
  public func timer( sec: Nat ) : Obs<()> {
    let obs = Subject<()>();

    let timerId = Timer.recurringTimer(#seconds sec, func() : async () {
          obs.next(());
      });

    ignore obs.subscribe({
       next = func () {};
       complete = func() {
            Timer.cancelTimer(timerId);
       }
      });
      
    return obs;
  };

  // Delay
  public func delay<X>( sec: Nat ) : (Obs<X>) -> (Obs<X>) {
    return func ( x : Obs<X> ) {
        Observable<X>( func (subscriber) {
          var timerId : ?Timer.TimerId = null; 
          ignore x.subscribe({
            next = func(v) {
                timerId := ?Timer.setTimer(#seconds sec, func() : async () {
                    subscriber.next( v )
                });
            };
            complete = func (v) {
              switch(timerId) {
                case (?id) Timer.cancelTimer(id);
                case (null) ();
              };
              subscriber.complete();
              }
          })
        });
      }
  };

  //
  public func timerOnce( sec: Nat ) : Obs<()> {

    let obs = Subject<()>();

    let cancel = Timer.setTimer(#seconds sec, func() : async () {
          obs.next();
      });

    return obs;
  };

  // Emits the values emitted by the source Observable until a notifier Observable emits a value.
  // `takeUntil` subscribes and begins mirroring the source Observable. It also
  // monitors a second Observable, `notifier` that you provide. If the `notifier`
  // emits a value, the output Observable stops mirroring the source Observable
  // and completes. If the `notifier` doesn't emit any value and completes
  // then `takeUntil` will pass all values.
  public func takeUntil<X,Y>( obsUntil: Obs<Y> ) : (Obs<X>) -> (Obs<X>) {
    return func ( x : Obs<X> ) {
        var isComplete : Bool = false;
        Observable<X>( func (subscriber) {

          ignore obsUntil.subscribe({
            next = func (v) { 
              if (isComplete) return;
              isComplete := true;
              subscriber.complete();
              };
            complete = func () {}
          });

          ignore x.subscribe({
            next = func(v) {
               if (isComplete) return;
               subscriber.next( v );
            };
            complete = func() {
              if (isComplete) return;
              isComplete := true;
              subscriber.complete();
            }
          })

        });

      }
  };


  // Applies an accumulator function over the source Observable, and returns the accumulated result when the source completes, given an optional initial value.
  public func reduce<X,Y>( project: (Y, X) -> (Y), initial: Y ) : (Obs<X>) -> (Obs<Y>) {
    var acc = initial; 
    return func ( x : Obs<X> ) {
        Observable<Y>( func (subscriber) {
          ignore x.subscribe({
            next = func(v) {
               acc := project(acc, v);
            };
            complete = func() {
              subscriber.next( acc );
              subscriber.complete();
            }
          })
        });
      }
  };

  // Applies a given project function to each value emitted by the source Observable,
  // and emits the resulting values as an Observable.
  public func map<X,Y>( project: (X) -> (Y) ) : (Obs<X>) -> (Obs<Y>) {
    return func ( x : Obs<X> ) {
        Observable<Y>( func (subscriber) {
          ignore x.subscribe({
            next = func(v) {
               subscriber.next( project(v))
            };
            complete = subscriber.complete
          })
        });
      }
  };

  //Returns an Observable that emits all items emitted by the source Observable that are distinct by comparison from previous items.
  public func distinct<X>( keySelect: (X) -> Blob ) : (Obs<X>) -> (Obs<X>) {
    return func ( x : Obs<X> ) {

        Observable<X>( func (subscriber) {

          var distinctKeys: TrieSet.Set<Blob> = TrieSet.empty<Blob>();

          ignore x.subscribe({
            next = func(v) {
              let myKey = keySelect(v);
              let myHash = Blob.hash(myKey);
              if (TrieSet.mem<Blob>(distinctKeys, myKey, myHash, Blob.equal) == false) {
                distinctKeys := TrieSet.put<Blob>(distinctKeys, myKey, myHash, Blob.equal);
                subscriber.next( v );
              };

            };
            complete = subscriber.complete
          })
        });
    }
  };


  // Emits only the first value (or the first value that meets some condition) emitted by the source Observable.
  public func first<X>( ) : (Obs<X>) -> (Obs<X>) {
    return func ( x : Obs<X> ) {
        Observable<X>( func (subscriber) {
          var first_one = true;
          ignore x.subscribe({
            next = func(v) {
               if (first_one == false) return;
               subscriber.next( v );
               first_one := false;
               subscriber.complete();
            };
            complete = func() {
               if (first_one == false) return;
               subscriber.complete();
            }
          })
        });
    }
  };

  // Joins every Observable emitted by the source (a higher-order Observable), in a serial fashion.
  // It subscribes to each inner Observable only after the previous inner Observable has completed, 
  // and merges all of their values into the returned observable.
  public func concatAll<X>( ) : (Obs<Obs<X>>) -> (Obs<X>) {
      mergeInternals<Obs<X>, X>(1, func (x) {x} )
  };

  // Projects each source value to an Observable which is merged in the output Observable.
  public func mergeMap<X,Y>( project: (X) -> (Obs<Y>), concurrent: Nat ) : (Obs<X>) -> (Obs<Y>) {
      mergeInternals<X,Y>(concurrent, project)
  };

  // A process embodying the general "merge" strategy.
  private func mergeInternals<X,Y>(concurrent : Nat, project: (X) -> (Obs<Y>) ) : (Obs<X>) -> (Obs<Y>) {
    return func ( x : Obs<X> ) {
        Observable<Y>( func (subscriber) {
          
          var active : Nat = 0; 
          var buffer : List.List<X> = List.nil();
          var isComplete = false;

          let checkComplete = func () {
              if (isComplete and List.size(buffer) == 0 and active == 0) {
                subscriber.complete();
              }
          };

          let doInnerSub = func (obs : X) {
            active += 1;

            ignore project(obs).subscribe({
              next = func (v: Y) {
                subscriber.next(v);
              };
              complete = func() {
                active -= 1;

                while (List.size(buffer) > 0 and active < concurrent) {
                  let ?bufferedValue = List.get(buffer, 0);
                  buffer := List.drop(buffer, 1);
                  doInnerSub(bufferedValue);
                };

                checkComplete();
              };
            });
          };
          
          ignore x.subscribe({
              next = func(value : X) {
                 if (active < concurrent) {
                      doInnerSub(value);
                    } else {
                      buffer := List.push(value, buffer);
                    }
              };
              complete = func() {
                  isComplete := true;
                  checkComplete();
                 
              };
          });
       
        });
    }
  };

  // Creates observable and emits values from array
  public func of<X>( arr : [X] ) : Obs<X> {
    Observable<X>( func (subscriber) {
        for (el in arr.vals()) {
          subscriber.next(el);
        };
        
        subscriber.complete();
    });
  };



  public type Listener<X> = {
    next : (X) -> ();
    complete : () -> ();
  };
    
  public func pipe2<A,B>(ob: Obs<A>, op1 : Operator<A,B>) : Obs<B> {
        op1(ob)
  };
   
  public func pipe3<A,B,C>(ob: Obs<A>, op1 : Operator<A,B>, op2 : Operator<B,C>) : Obs<C> {
        op2(op1(ob))
  };

  public func pipe4<A,B,C,D>(ob: Obs<A>, op1 : Operator<A,B>, op2 : Operator<B,C>, op3 : Operator<C,D>) : Obs<D> {
        op3(op2(op1(ob)))
  };

  public func pipe5<A,B,C,D,E>(ob: Obs<A>, op1 : Operator<A,B>, op2 : Operator<B,C>, op3 : Operator<C,D>, op4 : Operator<D,E>) : Obs<E> {
        op4(op3(op2(op1(ob))))
  };


  public type SubscriberFn<A> = (Listener<A>) -> ();


  public type UnsubscribeFn = () -> ();

  // Observable
  public class Obs<A>(
      otype : {#Observer: SubscriberFn<A>; #Subject}
      ) = this {

      // Subject specific
      var listeners = Buffer.Buffer<Listener<A>>(10);

      public func next( val: A ) : () {
        switch(otype) { case (#Observer(_)) return; case (_) (); };
        for (li in listeners.vals()) {
          li.next( val );
        }
      };

      public func complete() : () {
        switch(otype) { case (#Observer(_)) return; case (_) (); };
        for (li in listeners.vals()) {
          li.complete();
        }
      };
      // --- End Subject specific

      public func subscribe( z : Listener<A> ) : UnsubscribeFn {
        var ended : Bool = false;
        let unsubscribeFn :UnsubscribeFn = func() {
          ended := true;
        };
        let wrap:Listener<A> = {
          next = func (x) { if (ended == false) z.next(x) };
          complete = func (x) { if (ended == false) { z.complete(); unsubscribeFn(); } };
        };

        switch(otype) {
          case (#Observer(sub)) sub(wrap);
          case (#Subject) listeners.add(wrap);
        };

        unsubscribeFn;
      };

  };



  public func Subject<A>() : Obs<A>{
    Obs<A>(#Subject);
  };

  public func Observable<A>( sub : (Listener<A>) -> () ) : Obs<A>{
    Obs<A>(#Observer(sub));
  };


  public let null_func = func () {};
  
}