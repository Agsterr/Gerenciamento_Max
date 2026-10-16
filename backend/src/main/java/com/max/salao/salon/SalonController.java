package com.max.salao.salon;

import com.max.salao.salon.SalonDtos.SalonRequest;
import com.max.salao.salon.SalonDtos.SalonResponse;
import jakarta.validation.Valid;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/salon")
public class SalonController {

    private final SalonService service;

    public SalonController(SalonService service) {
        this.service = service;
    }

    @GetMapping
    public SalonResponse get() {
        return SalonResponse.from(service.current());
    }

    @PutMapping
    public SalonResponse update(@Valid @RequestBody SalonRequest req) {
        return SalonResponse.from(service.update(req));
    }
}
