package com.emsi.telemedicine.exception;

/** Ressource demandée introuvable -> HTTP 404. */
public class ResourceNotFoundException extends RuntimeException {

    public ResourceNotFoundException(String message) {
        super(message);
    }
}
