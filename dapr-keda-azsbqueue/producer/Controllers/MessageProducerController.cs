﻿using System.Threading.Tasks;
using Microsoft.AspNetCore.Mvc;
using System.Net.Http;
using producer.Models;
using Newtonsoft.Json;
using System.Text;
using Newtonsoft.Json.Serialization;
using System.Collections.Generic;
using System.Net;

namespace producer.Controllers
{
    [ApiController]
    [Route("[controller]")]
    public class MessageProducerController : ControllerBase
    {
        [HttpPost]
        public async Task<IActionResult> Produce([FromBody]Produce produce)
        {
            var daprport = "3500";
            var daprUrl = $"http://localhost:{daprport}/v1.0/bindings/message-queue";

            for (var i = 0; i < produce.Count; i++)
            {
                var msg = new Message
                {
                    Text = "Hello World"
                };

                var payload = new
                {
                    data = msg,
                    operation = "create"
                };

                var client = new HttpClient();
                var data = JsonConvert.SerializeObject(payload, new JsonSerializerSettings { ContractResolver = new CamelCasePropertyNamesContractResolver() });
                var result = await client.PostAsync(daprUrl, new StringContent(data, Encoding.UTF8, "application/json"));

                if (!result.IsSuccessStatusCode)
                {
                    var text = result.Content.ReadAsStringAsync();
                    return StatusCode((int)HttpStatusCode.InternalServerError, text);
                }

                await Task.Delay(produce.IntervalMilliseconds);
            }

            return Ok();
        }
    }
}
