using Microsoft.AspNetCore.Mvc;

namespace AspnetCoreEchoApi.Controllers
{
    [ApiController]
    [Route("[controller]")]
    public class EchoController : ControllerBase
    {
        [HttpGet("{message}")]
        public string Echo(string message)
        {
            return message;
        }
    }
}