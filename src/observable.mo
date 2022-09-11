import List "mo:base/List";
import Buffer "mo:base/Buffer";
import Debug "mo:base/Debug";

module {

  public type Operator<X,Y> = (Obs<X>) -> (Obs<Y>);

  // Applies a given project function to each value emitted by the source Observable,
  // and emits the resulting values as an Observable.
  public func map<X,Y>( project: (X) -> (Y) ) : (Obs<X>) -> (Obs<Y>) {
    return func ( x : Obs<X> ) {
        Observable<Y>( func (subscriber) {
          x.subscribe({
            next = func(v) {
               subscriber.next( project(v))
            };
            complete = func() {
               subscriber.complete()
            }
          })
        });
    }
  };


  // Emits only the first value (or the first value that meets some condition) emitted by the source Observable.
  public func first<X>( ) : (Obs<X>) -> (Obs<X>) {
    return func ( x : Obs<X> ) {
        Observable<X>( func (subscriber) {
          var first_one = true;
          x.subscribe({
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

            project(obs).subscribe({
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
          
          x.subscribe({
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

      public func subscribe( fn : Listener<A> ) : () {
        switch(otype) {
          case (#Observer(sub)) sub(fn);
          case (#Subject) listeners.add(fn);
        }
      };

  };



  public func Subject<A>() : Obs<A>{
    Obs<A>(#Subject);
  };

  public func Observable<A>( sub : (Listener<A>) -> () ) : Obs<A>{
    Obs<A>(#Observer(sub));
  };


}