package com.emsi.telemedicine.dto;

import java.util.List;

/**
 * Format JSON uniforme des erreurs renvoyées par l'API.
 */
public record ErrorResponse(int status, String message, List<String> details) {

    public ErrorResponse(int status, String message) {
        this(status, message, List.of());
    }
}
