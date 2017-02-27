import Foundation

extension Array
{
    func mapi<U>(_ transform: (Int, Element) -> U) -> [U]
    {
        var result = [U]()
        result.reserveCapacity(self.count)
        
        for (i, e) in self.enumerated()
        {
            result.append(transform(i, e))
        }
        
        return result
    }
}
