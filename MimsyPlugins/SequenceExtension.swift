import Foundation

extension Sequence
{
    
    public func countFiltered(includeElement: (Self.Iterator.Element) throws -> Bool) rethrows -> Int
    {
        var count = 0
        
        var generator = self.makeIterator()
        while (true)
        {
            if let element = generator.next()
            {
                if try includeElement(element)
                {
                    count += 1
                }
            }
            else
            {
                break
            }
        }
        
        return count
    }
}
