using System;
using System.Collections.Generic;
using System.Net;
using System.Net.Http;
using System.Text.Json;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Mvc;

namespace api_aspnetcore.Controllers
{
    [ApiController]
    [Route("[controller]")]
    public class SecretController : ControllerBase
    {
        private static int _daprPort = 3500;
        private static string _secretsUrl = $"http://localhost:{_daprPort}/v1.0/secrets";
        private static string _secretStoreName = "azurekeyvault";
        private static string _secretOne = "secretone";
        private static string _secretTwo = "secrettwo";

        [HttpGet]
        public async Task<IActionResult> GetSecrets()
        {
            try
            {
                var client = new HttpClient();
                var result = await client.GetAsync($"{_secretsUrl}/{_secretStoreName}/{_secretOne}");

                if (!result.IsSuccessStatusCode)
                {
                    return StatusCode((int)HttpStatusCode.InternalServerError);
                }

                var json = await result.Content.ReadAsStringAsync();
                System.Console.WriteLine(json);
                var dict = JsonSerializer.Deserialize<Dictionary<string, string>>(json);
                var secretOne = dict[_secretOne];

                result = await client.GetAsync($"{_secretsUrl}/{_secretStoreName}/{_secretTwo}");

                if (!result.IsSuccessStatusCode)
                {
                    return StatusCode((int)HttpStatusCode.InternalServerError);
                }

                json = await result.Content.ReadAsStringAsync();
                dict = JsonSerializer.Deserialize<Dictionary<string, string>>(json);
                var secretTwo = dict[_secretTwo];

                return Ok($"Result from aspnetcore API: SecretOne: {secretOne} | SecretTwo: {secretTwo}");
            }
            catch (Exception ex)
            {
                return Ok(ex.Message);
            }
        }
    }
}