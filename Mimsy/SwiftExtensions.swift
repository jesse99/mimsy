import Foundation

extension Array
{
    func mapi<U>(transform: (Int, T) -> U) -> [U]
    {
        var result = [U]()
        result.reserveCapacity(self.count)
        
        for (i, e) in enumerate(self)
        {
            result.append(transform(i, e))
        }
        
        return result
    }
}