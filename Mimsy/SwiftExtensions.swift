import Foundation

extension Array
{
    func mapi<U>(transform: (Int, Element) -> U) -> [U]
    {
        var result = [U]()
        result.reserveCapacity(self.count)
        
        for (i, e) in self.enumerate()
        {
            result.append(transform(i, e))
        }
        
        return result
    }
}