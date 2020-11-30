using System;
using System.Threading;
using System.Threading.Tasks;
using Azure.Storage.Queues;
using Azure.Storage.Queues.Models;

namespace kedaqueue
{
    class Program
    {
        private static readonly CancellationTokenSource canToken = new CancellationTokenSource();
        static void Main(string[] args)
        {
            var queueConnection = Environment.GetEnvironmentVariable("QCONNECTION");

            QueueClient queue = new QueueClient(queueConnection, "keda");

            Console.CancelKeyPress += new ConsoleCancelEventHandler(cancelHandler);

            while (!canToken.IsCancellationRequested)
            {
                foreach (QueueMessage message in queue.ReceiveMessages(maxMessages: 1).Value)
                {
                    Console.WriteLine($"Message: {message.Body}");
                    queue.DeleteMessage(message.MessageId, message.PopReceipt);
                }
                Console.WriteLine("Waiting 5 seconds.");
                Task.Delay(5000).Wait();
            }
        }

        protected static void cancelHandler(object sender, ConsoleCancelEventArgs args)
        {
            Console.WriteLine("Cancelling...");
            canToken.Cancel();
            args.Cancel = true;
        }
    }
}
